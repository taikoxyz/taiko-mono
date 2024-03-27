package rabbitmq

import (
	"context"
	"fmt"
	"log/slog"
	"sync"
	"time"

	"github.com/google/uuid"
	amqp "github.com/rabbitmq/amqp091-go"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
)

type RabbitMQ struct {
	conn              *amqp.Connection
	ch                *amqp.Channel
	queue             amqp.Queue
	unprofitableQueue amqp.Queue
	opts              queue.NewQueueOpts

	connErrCh chan *amqp.Error

	chErrCh chan *amqp.Error

	notifyReturnCh chan amqp.Return

	subscriptionCtx    context.Context
	subscriptionCancel context.CancelFunc
}

func NewQueue(opts queue.NewQueueOpts) (*RabbitMQ, error) {
	slog.Info("dialing rabbitmq connection")

	r := &RabbitMQ{
		opts: opts,
	}

	err := r.connect()
	if err != nil {
		return nil, err
	}

	return r, nil
}

func (r *RabbitMQ) connect() error {
	slog.Info("connecting to rabbitmq")

	if r.subscriptionCancel != nil {
		r.subscriptionCancel()
	}

	conn, err := amqp.DialConfig(
		fmt.Sprintf(
			"amqp://%v:%v@%v:%v/",
			r.opts.Username,
			r.opts.Password,
			r.opts.Host,
			r.opts.Port,
		), amqp.Config{
			Heartbeat: 1 * time.Second,
		})
	if err != nil {
		relayer.QueueConnectionInstantiatedErrors.Inc()

		return err
	}

	ch, err := conn.Channel()
	if err != nil {
		relayer.QueueConnectionInstantiatedErrors.Inc()

		return err
	}

	if err := ch.Qos(int(r.opts.PrefetchCount), 0, false); err != nil {
		relayer.QueueConnectionInstantiatedErrors.Inc()

		return err
	}

	r.conn = conn
	r.ch = ch

	r.connErrCh = r.conn.NotifyClose(make(chan *amqp.Error))

	r.chErrCh = r.ch.NotifyClose(make(chan *amqp.Error))

	r.subscriptionCtx, r.subscriptionCancel = context.WithCancel(context.Background())

	slog.Info("connected to rabbitmq")

	relayer.QueueConnectionInstantiated.Inc()

	return nil
}

func (r *RabbitMQ) Start(ctx context.Context, queueName string) error {
	dlxQueue := fmt.Sprintf("dlx-%v", queueName)

	exchange := "messages"

	dlxExchange := "messages-dlx"

	routingKey := fmt.Sprintf("%v-process", queueName)

	routingKeyUnprofitable := fmt.Sprintf("%v-unprofitable", queueName)

	slog.Info("declaring rabbitmq dlx exchange", "exchange", dlxExchange)

	// declare the dead letter exchange for when a message is negatively acknowledged
	// with no requeue
	if err := r.ch.ExchangeDeclare(
		dlxExchange,
		"direct",
		true,
		false,
		false,
		false,
		nil,
	); err != nil {
		return err
	}

	slog.Info("declaring rabbitmq exchange", "exchange", exchange)

	if err := r.ch.ExchangeDeclare(
		exchange,
		"direct",
		true,
		false,
		false,
		false,
		nil,
	); err != nil {
		return err
	}

	slog.Info("declaring rabbitmq dlx queue", "queue", dlxQueue)

	// declare the queue on the dead letter exchange they should be routed to
	if _, err := r.ch.QueueDeclare(
		dlxQueue,
		true,
		false,
		false,
		false,
		map[string]interface{}{
			"x-dead-letter-exchange":    exchange,
			"x-dead-letter-routing-key": routingKey,
		},
	); err != nil {
		return err
	}

	slog.Info("binding dlx exchange and dlx exchange")

	if err := r.ch.QueueBind(dlxQueue, routingKey, dlxExchange, false, nil); err != nil {
		return err
	}

	slog.Info("declaring rabbitmq queue", "queue", queueName)

	args := amqp.Table{}

	args["x-dead-letter-exchange"] = dlxExchange

	q, err := r.ch.QueueDeclare(
		queueName,
		true,
		false,
		false,
		false,
		args,
	)
	if err != nil {
		return err
	}

	slog.Info("binding queue and exchange", "queue", queueName, "exchange", exchange)

	if err := r.ch.QueueBind(queueName, routingKey, exchange, false, nil); err != nil {
		return err
	}

	// we declare a queue where unprofitable messages go, which no
	// consumer listens on. We add an expiration to them, and a dead-letter exchange
	// of the original exchange and queue for processing messages, so once
	// they are expired, they will be picked up again to check in the normal
	// processing flow.
	unprofitableArgs := amqp.Table{}

	// we set the routing key to be the process message routing key, not the unprofitable
	// message routing key.
	unprofitableArgs["x-dead-letter-exchange"] = exchange
	unprofitableArgs["x-dead-letter-routing-key"] = routingKey

	unprofitableQueueName := fmt.Sprintf("%v-unprofitable", queueName)

	unprofitableQueue, err := r.ch.QueueDeclare(
		unprofitableQueueName,
		true,
		false,
		false,
		false,
		unprofitableArgs,
	)
	if err != nil {
		return err
	}

	slog.Info("binding queue and exchange", "queue", unprofitableQueueName, "exchange", exchange)

	if err := r.ch.QueueBind(unprofitableQueueName, routingKeyUnprofitable, exchange, false, nil); err != nil {
		return err
	}

	r.queue = q

	r.unprofitableQueue = unprofitableQueue

	return nil
}

func (r *RabbitMQ) Close(ctx context.Context) {
	if err := r.ch.Close(); err != nil {
		if err != amqp.ErrClosed {
			slog.Info("error closing rabbitmq connection", "err", err.Error())
		}
	}

	slog.Info("closed rabbitmq channel")

	if err := r.conn.Close(); err != nil {
		if err != amqp.ErrClosed {
			slog.Info("error closing rabbitmq connection", "err", err.Error())
		}
	}

	slog.Info("closed rabbitmq connection")
}

func (r *RabbitMQ) Publish(ctx context.Context, queueName string, msg []byte, expiration *string) error {
	slog.Info("publishing rabbitmq msg to queue", "queue", r.queue.Name)

	p := amqp.Publishing{
		ContentType:  "text/plain",
		Body:         msg,
		MessageId:    uuid.New().String(),
		DeliveryMode: 2, // persistent messages, saved to disk to survive server restart
	}

	if expiration != nil {
		p.Expiration = *expiration
	}

	err := r.ch.PublishWithContext(ctx,
		"",
		queueName,
		true,
		false,
		p,
	)
	if err != nil {
		relayer.QueueMessagePublishedErrors.Inc()

		if err == amqp.ErrClosed {
			slog.Error("amqp channel closed", "err", err.Error())

			err := r.connect()
			if err != nil {
				return err
			}

			return r.Publish(ctx, queueName, msg, expiration)
		} else {
			return err
		}
	}

	relayer.QueueMessagePublished.Inc()

	return nil
}

func (r *RabbitMQ) Ack(ctx context.Context, msg queue.Message) error {
	rmqMsg := msg.Internal.(amqp.Delivery)

	err := rmqMsg.Ack(false)

	if err != nil {
		slog.Error("error acknowledging rabbitmq message", "err", err.Error())
		return err
	}

	slog.Info("acknowledged rabbitmq message", "msgId", rmqMsg.MessageId)

	relayer.QueueMessageAcknowledged.Inc()

	return nil
}

func (r *RabbitMQ) Nack(ctx context.Context, msg queue.Message, requeue bool) error {
	rmqMsg := msg.Internal.(amqp.Delivery)

	err := rmqMsg.Nack(false, requeue)
	if err != nil {
		slog.Error("error negatively acknowledging rabbitmq message", "err", err.Error())
		return err
	}

	slog.Info("negatively acknowledged rabbitmq message", "msgId", rmqMsg.MessageId, "requeue", requeue)

	relayer.QueueMessageNegativelyAcknowledged.Inc()

	return nil
}

// Notify should be called by publishers who wish to be notified of subscription errors.
func (r *RabbitMQ) Notify(ctx context.Context, wg *sync.WaitGroup) error {
	wg.Add(1)

	defer func() {
		wg.Done()
	}()

	slog.Info("rabbitmq notify running")

	for {
		select {
		case <-ctx.Done():
			slog.Info("rabbitmq context closed")

			return nil
		case err := <-r.connErrCh:
			if err != nil {
				slog.Error("rabbitmq notify close connection", "err", err.Error())
			} else {
				slog.Error("rabbitmq notify close connection")
			}

			relayer.QueueConnectionNotifyClosed.Inc()

			r.Close(ctx)

			if err := r.connect(); err != nil {
				slog.Error("error reconnecting to rabbitmq after notify closed", "err", err.Error())
				return err
			}

			return queue.ErrClosed
		case err := <-r.chErrCh:
			if err != nil {
				slog.Error("rabbitmq notify close channel", "err", err.Error())
			} else {
				slog.Error("rabbitmq notify close channel")
			}

			relayer.QueueChannelNotifyClosed.Inc()

			r.Close(ctx)

			if err := r.connect(); err != nil {
				slog.Error("error reconnecting to rabbitmq after notify closed", "err", err.Error())
				return err
			}

			return queue.ErrClosed
		case returnMsg := <-r.notifyReturnCh:
			slog.Error("rabbitmq notify return", "id", returnMsg.MessageId, "err", returnMsg.ReplyText)
			slog.Info("rabbitmq attempting republish of returned msg", "id", returnMsg.MessageId)

			if err := r.Publish(ctx, r.queue.Name, returnMsg.Body, &returnMsg.Expiration); err != nil {
				slog.Error("error publishing msg", "err", err.Error())
			}
		}
	}
}

// Subscribe should be called by consumers.
func (r *RabbitMQ) Subscribe(ctx context.Context, msgChan chan<- queue.Message, wg *sync.WaitGroup) error {
	wg.Add(1)

	defer func() {
		wg.Done()
	}()

	slog.Info("subscribing to rabbitmq messages", "queue", r.queue.Name)

	msgs, err := r.ch.Consume(
		r.queue.Name,
		"",
		false, // disable auto-acknowledge until after processing
		false,
		false,
		false,
		nil,
	)

	if err != nil {
		if err == amqp.ErrClosed {
			slog.Info("cant subscribe to rabbitmq, channel closed. attempting reconnection")

			if err := r.connect(); err != nil {
				slog.Error("error reconnecting to channel during subscribe", "err", err.Error())
				return err
			}

			msgs, err = r.ch.Consume(
				r.queue.Name,
				"",
				false, // disable auto-acknowledge until after processing
				false,
				false,
				false,
				nil,
			)
			if err != nil {
				return err
			}
		} else {
			return err
		}
	}

	for {
		select {
		case <-r.subscriptionCtx.Done():
			defer r.Close(ctx)

			slog.Info("rabbitmq subscription ctx cancelled")

			return queue.ErrClosed
		case <-ctx.Done():
			defer r.Close(ctx)

			slog.Info("rabbitmq context cancelled")

			return nil
		case err := <-r.connErrCh:
			slog.Error("rabbitmq notify close connection", "err", err.Error())

			return queue.ErrClosed
		case err := <-r.chErrCh:
			slog.Error("rabbitmq notify close channel", "err", err.Error())

			return queue.ErrClosed
		case d, ok := <-msgs:
			if !ok {
				slog.Error("rabbitmq msg channel was closed")
				return queue.ErrClosed
			}

			if d.Body != nil {
				slog.Info("rabbitmq message found", "msgId", d.MessageId)

				var timesRetried int64 = 0

				var maxRetries int64 = 3

				xDeath, exists := d.Headers["x-death"].([]interface{})

				if exists {
					// message was rejected before
					c := xDeath[0].(amqp.Table)["count"].(int64)

					timesRetried = c

					if timesRetried > 0 {
						relayer.MessageSentEventsRetries.Inc()
					}
				}

				if timesRetried > 0 {
					slog.Info("rabbitmq message times retried",
						"msgId", d.MessageId,
						"timesRetried", timesRetried,
					)
				}

				if timesRetried >= int64(maxRetries) {
					slog.Info("msg has reached max retries", "id", d.MessageId)

					relayer.MessageSentEventsMaxRetriesReached.Inc()

					if err := d.Ack(false); err != nil {
						slog.Error("error acking msg after max retries")
					}
				} else {
					msgChan <- queue.Message{
						Body:         d.Body,
						Internal:     d,
						TimesRetried: timesRetried,
					}
				}
			} else {
				slog.Info("nil body message, queue is closed")
				return queue.ErrClosed
			}
		}
	}
}
