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
}

func NewQueue(opts queue.NewQueueOpts) (*RabbitMQ, error) {
	slog.Info("dialing rabbitmq connection")

	conn, err := amqp.Dial(
		fmt.Sprintf(
			"amqp://%v:%v@%v:%v/",
			opts.Username,
			opts.Password,
			opts.Host,
			opts.Port,
		))
	if err != nil {
		return nil, err
	}

	ch, err := conn.Channel()
	if err != nil {
		return nil, err
	}

	return &RabbitMQ{
		conn: conn,
		ch:   ch,
	}, nil
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
	defer r.conn.Close()
	defer r.ch.Close()
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
		return err
	}

	return nil
}

func (r *RabbitMQ) Ack(ctx context.Context, msg queue.Message) error {
	rmqMsg := msg.Internal.(amqp.Delivery)

	slog.Info("acknowledging rabbitmq message", "msgId", rmqMsg.MessageId)

	return rmqMsg.Ack(false)
}

func (r *RabbitMQ) Nack(ctx context.Context, msg queue.Message) error {
	rmqMsg := msg.Internal.(amqp.Delivery)

	slog.Info("acknowledging rabbitmq message", "msgId", rmqMsg.MessageId)

	return rmqMsg.Nack(false, false)
}

func (r *RabbitMQ) Subscribe(ctx context.Context, msgChan chan<- queue.Message, wg *sync.WaitGroup) error {
	defer func() {
		wg.Done()
	}()

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
	go func() {
		for {
			select {
			case <-ctx.Done():
				defer r.Close(ctx)
				return

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
					// error with channel if we got a nil body message
					// it wont be able to be acknowledged.
					// re-establish connection
					ch, err := r.conn.Channel()
					if err != nil {
						slog.Error("error establishing channel", "err", err.Error())
					}

					r.ch = ch

					if err := r.Start(ctx, r.queue.Name); err != nil {
						slog.Error("error starting queue", "err", err.Error())
					}
				}
			}
		}
	}()

	return nil
}
