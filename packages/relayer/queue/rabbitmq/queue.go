package rabbitmq

import (
	"context"
	"fmt"
	"log/slog"
	"sync"

	amqp "github.com/rabbitmq/amqp091-go"
	"github.com/taikoxyz/taiko-mono/packages/relayer/queue"
)

type RabbitMQ struct {
	conn  *amqp.Connection
	ch    *amqp.Channel
	queue amqp.Queue
	opts  queue.NewQueueOpts
}

func NewQueue(opts queue.NewQueueOpts) (*RabbitMQ, error) {
	slog.Info("dialing rabbitmq connection")

	conn, ch, err := connect(opts)
	if err != nil {
		return nil, err
	}

	return &RabbitMQ{
		conn: conn,
		ch:   ch,
		opts: opts,
	}, nil
}

func connect(opts queue.NewQueueOpts) (*amqp.Connection, *amqp.Channel, error) {
	slog.Info("connecting to rabbitmq")

	conn, err := amqp.Dial(
		fmt.Sprintf(
			"amqp://%v:%v@%v:%v/",
			opts.Username,
			opts.Password,
			opts.Host,
			opts.Port,
		))
	if err != nil {
		return nil, nil, err
	}

	ch, err := conn.Channel()
	if err != nil {
		return nil, nil, err
	}

	slog.Info("connected to rabbitmq")

	return conn, ch, nil
}

func (r *RabbitMQ) Start(ctx context.Context, queueName string) error {
	slog.Info("declaring rabbitmq queue", "queue", queueName)

	q, err := r.ch.QueueDeclare(
		queueName,
		false,
		false,
		false,
		false,
		nil,
	)
	if err != nil {
		return err
	}

	r.queue = q

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

func (r *RabbitMQ) Publish(ctx context.Context, msg []byte) error {
	slog.Info("publishing rabbitmq msg to queue", "queue", r.queue.Name)

	err := r.ch.PublishWithContext(ctx,
		"",
		r.queue.Name,
		false,
		false,
		amqp.Publishing{
			ContentType: "text/plain",
			Body:        msg,
		})
	if err != nil {
		if err == amqp.ErrClosed {
			slog.Error("amqp channel closed", "err", err.Error())

			conn, ch, err := connect(r.opts)
			if err != nil {
				return err
			}

			r.conn = conn
			r.ch = ch

			return r.Publish(ctx, msg)
		} else {
			return err
		}
	}

	return nil
}

func (r *RabbitMQ) Ack(ctx context.Context, msg queue.Message) error {
	rmqMsg := msg.Internal.(amqp.Delivery)

	slog.Info("acknowledging rabbitmq message", "msgId", rmqMsg.MessageId)

	err := rmqMsg.Ack(false)
	if err != nil {
		if err == amqp.ErrClosed {
			slog.Error("amqp channel closed", "err", err.Error())

			r.Close(ctx)

			conn, ch, err := connect(r.opts)
			if err != nil {
				return err
			}

			r.conn = conn
			r.ch = ch

			return r.Ack(ctx, msg)
		} else {
			return err
		}
	}

	return nil
}

func (r *RabbitMQ) Nack(ctx context.Context, msg queue.Message) error {
	rmqMsg := msg.Internal.(amqp.Delivery)

	slog.Info("acknowledging rabbitmq message", "msgId", rmqMsg.MessageId)

	err := rmqMsg.Nack(false, false)
	if err != nil {
		if err == amqp.ErrClosed {
			slog.Error("amqp channel closed", "err", err.Error())

			conn, ch, err := connect(r.opts)
			if err != nil {
				return err
			}

			r.conn = conn
			r.ch = ch

			return r.Nack(ctx, msg)
		} else {
			return err
		}
	}

	return nil
}

func (r *RabbitMQ) Subscribe(ctx context.Context, msgChan chan<- queue.Message, wg *sync.WaitGroup) error {
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
		return err
	}

	// wrap internal msg chan with a generic queue
	for {
		select {
		case <-ctx.Done():
			r.Close(ctx)
			return nil

		case d := <-msgs:
			if d.Body != nil {
				slog.Info("rabbitmq message found", "msgId", d.MessageId)
				{
					msgChan <- queue.Message{
						Body:     d.Body,
						Internal: d,
					}
				}
			} else {
				return queue.ErrClosed
			}
		}
	}
}
