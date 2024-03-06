package relayer

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	QueueMessageAcknowledged = promauto.NewCounter(prometheus.CounterOpts{
		Name: "queue_message_acknowledged_ops_total",
		Help: "The total number of acknowledged queue events",
	})
	QueueMessageNegativelyAcknowledged = promauto.NewCounter(prometheus.CounterOpts{
		Name: "queue_message_negatively_acknowledged_ops_total",
		Help: "The total number of negatively acknowledged queue events",
	})
	QueueChannelNotifyClosed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "queue_channel_notify_closed_ops_total",
		Help: "The total number of times a queue channel was notified as closed",
	})
	QueueConnectionNotifyClosed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "queue_connection_notify_closed_ops_total",
		Help: "The total number of times a queue connection was notified as closed",
	})
	QueueMessagePublished = promauto.NewCounter(prometheus.CounterOpts{
		Name: "queue_message_published_ops_total",
		Help: "The total number of times a queue message was published",
	})
	QueueMessagePublishedErrors = promauto.NewCounter(prometheus.CounterOpts{
		Name: "queue_message_published_errors_ops_total",
		Help: "The total number of times a queue message was published with an error",
	})
	QueueConnectionInstantiated = promauto.NewCounter(prometheus.CounterOpts{
		Name: "queue_connection_instantiated_ops_total",
		Help: "The total number of times a queue connection was instantiated",
	})
	QueueConnectionInstantiatedErrors = promauto.NewCounter(prometheus.CounterOpts{
		Name: "queue_connection_instantiated_errors_ops_total",
		Help: "The total number of times a queue connection was instantiated with an error",
	})
	ChainDataSyncedEventsIndexed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "chain_data_synced_events_indexed_ops_total",
		Help: "The total number of ChainDataSynced indexed events",
	})
	MessageSentEventsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "message_sent_events_processed_ops_total",
		Help: "The total number of MessageSent processed events",
	})
	MessageSentEventsIndexed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "message_sent_events_indexed_ops_total",
		Help: "The total number of MessageSent indexed events",
	})
	MessageSentEventsIndexingErrors = promauto.NewCounter(prometheus.CounterOpts{
		Name: "message_sent_events_indexing_errors_ops_total",
		Help: "The total number of errors indexing MessageSent events",
	})
	MessageSentEventsRetries = promauto.NewCounter(prometheus.CounterOpts{
		Name: "message_sent_events_retries_ops_total",
		Help: "The total number of MessageSent events retries",
	})
	MessageReceivedEventsIndexingErrors = promauto.NewCounter(prometheus.CounterOpts{
		Name: "message_received_events_indexing_errors_ops_total",
		Help: "The total number of errors indexing MessageReceived events",
	})
	MessageStatusChangedEventsIndexed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "message_status_changed_events_indexed_ops_total",
		Help: "The total number of MessageStatusChanged indexed events",
	})
	MessageStatusChangedEventsIndexingErrors = promauto.NewCounter(prometheus.CounterOpts{
		Name: "message_status_changed_events_indexing_errors_ops_total",
		Help: "The total number of errors indexing MessageStatusChanged events",
	})
	ChainDataSyncedEventsIndexingErrors = promauto.NewCounter(prometheus.CounterOpts{
		Name: "chain_data_synced_events_indexing_errors_ops_total",
		Help: "The total number of errors indexing ChainDataSynced events",
	})
	BlocksProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "blocks_processed_ops_total",
		Help: "The total number of processed blocks",
	})
	TransactionsSuspended = promauto.NewCounter(prometheus.CounterOpts{
		Name: "transactions_suspended_ops_total",
		Help: "The total number of suspended transactions",
	})
	BlocksScanned = promauto.NewCounter(prometheus.CounterOpts{
		Name: "blocks_scanned_ops_total",
		Help: "The total number of scanned blocks. Acts as heartbeat metric.",
	})
	BlocksScannedError = promauto.NewCounter(prometheus.CounterOpts{
		Name: "blocks_scanned_error_ops_total",
		Help: "The total number of scanned block errors.",
	})
	RetriableEvents = promauto.NewCounter(prometheus.CounterOpts{
		Name: "events_processed_retriable_status_ops_total",
		Help: "The total number of processed events that ended up in Retriable status",
	})
	DoneEvents = promauto.NewCounter(prometheus.CounterOpts{
		Name: "events_processed_done_status_ops_total",
		Help: "The total number of processed events that ended up in Done status",
	})
	ErrorEvents = promauto.NewCounter(prometheus.CounterOpts{
		Name: "events_processed_error_ops_total",
		Help: "The total number of processed events that failed due to an error",
	})
	MessagesNotReceivedOnDestChain = promauto.NewCounter(prometheus.CounterOpts{
		Name: "messages_not_received_on_dest_chain_opts_total",
		Help: "The total number of messages that were not received on the destination chain",
	})
	ErrorsEncounteredDuringSubscription = promauto.NewCounter(prometheus.CounterOpts{
		Name: "errors_encountered_during_subscription_opts_total",
		Help: "The total number of errors that occurred during active subscription",
	})
)
