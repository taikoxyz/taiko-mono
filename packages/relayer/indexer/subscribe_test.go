package indexer

// TODO: WatchChainDataSynced returns
// panic: runtime error: invalid memory address or nil pointer dereference
// Re-enable it later
// func Test_subscribe(t *testing.T) {
// 	svc, bridge := newTestService(Sync, Subscribe)

// 	go func() {
// 		_ = svc.subscribe(context.Background(), mock.MockChainID)
// 	}()

// 	<-time.After(6 * time.Second)

// 	b := bridge.(*mock.Bridge)

// 	assert.Equal(t, 1, b.MessagesSent)
// 	assert.Equal(t, 1, b.MessageStatusesChanged)
// 	assert.Equal(t, 2, b.ErrorsSent)
// }
