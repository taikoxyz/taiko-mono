package p2p

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"sync"
	"time"

	"github.com/libp2p/go-libp2p"
	kaddht "github.com/libp2p/go-libp2p-kad-dht"
	pubsub "github.com/libp2p/go-libp2p-pubsub"
	"github.com/libp2p/go-libp2p/core/host"
	"github.com/libp2p/go-libp2p/core/network"
	"github.com/libp2p/go-libp2p/core/peer"
	discovery "github.com/libp2p/go-libp2p/p2p/discovery/routing"
	"github.com/multiformats/go-multiaddr"
)

const defaultPeerDiscoveryInternal = 1 * time.Second

const rendezvous = "taiko-p2p"

const TopicNameSoftBlocks = "soft-blocks"

type topicHandlerFunc[T any] func(context.Context, T) error

type Network struct {
	host             host.Host
	ps               *pubsub.PubSub
	routingDiscovery *discovery.RoutingDiscovery
	topics           map[string]*pubsub.Topic
	topicHandlers    map[string]any
	bootstrapNodeURL string
	localFullAddr    string
	fullAddr         string
	peers            []*peer.AddrInfo
	peersMutex       sync.Mutex
	receivedMessages int
}

func NewNetwork(ctx context.Context, bootstrapNodeURL string, port uint64) (*Network, error) {
	host, err := libp2p.New(
		libp2p.ListenAddrs(multiaddr.StringCast(fmt.Sprintf("/ip4/0.0.0.0/tcp/%v", port))),
	)
	if err != nil {
		return nil, err
	}

	localFullAddr := fmt.Sprintf("%s/p2p/%s", strings.ReplaceAll(host.Addrs()[0].String(), "]", ""), host.ID())

	fullAddr := fmt.Sprintf("%s/p2p/%s", strings.ReplaceAll(host.Addrs()[1].String(), "]", ""), host.ID())

	slog.Info("Node address", "address", fullAddr)

	slog.Info("Node started", "id", host.ID())

	kademliaDHT, err := kaddht.New(ctx, host)
	if err != nil {
		return nil, err
	}

	n := &Network{
		host:             host,
		topics:           make(map[string]*pubsub.Topic),
		topicHandlers:    make(map[string]any),
		bootstrapNodeURL: bootstrapNodeURL,
		localFullAddr:    localFullAddr,
		fullAddr:         fullAddr,
		peers:            make([]*peer.AddrInfo, 0),
	}

	n.acceptIncomingPeers()

	err = bootstrapDHT(ctx, n, bootstrapNodeURL, host, kademliaDHT)
	if err != nil {
		return nil, err
	}

	ps, err := pubsub.NewGossipSub(ctx, host)
	if err != nil {
		return nil, err
	}

	routingDiscovery := discovery.NewRoutingDiscovery(kademliaDHT)

	n.ps = ps
	n.routingDiscovery = routingDiscovery

	go n.startAdvertising(ctx)

	return n, nil
}

func (n *Network) startAdvertising(ctx context.Context) {
	t := time.NewTicker(defaultPeerDiscoveryInternal)
	defer t.Stop()

	// Find peers first to populate the routing table
	peerChan, err := n.routingDiscovery.FindPeers(ctx, rendezvous)
	if err != nil {
		slog.Warn("Failed to find peers", "err", err)
	}

	n.peersMutex.Lock()
	for peerInfo := range peerChan {
		slog.Info("Discovered peer", "peer", peerInfo.ID)
		// Check if peer is already added
		for _, p := range n.peers {
			if p.ID == peerInfo.ID {
				continue
			}
		}

		if peerInfo.ID == n.host.ID() {
			continue
		}

		n.peers = append(n.peers, &peerInfo)
	}
	n.peersMutex.Unlock()

	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			_, _ = n.routingDiscovery.Advertise(ctx, rendezvous)
		}
	}
}

func (n *Network) acceptIncomingPeers() {
	n.host.Network().Notify(&network.NotifyBundle{
		ConnectedF: func(_ network.Network, conn network.Conn) {
			peerID := conn.RemotePeer()

			addrInfo := peer.AddrInfo{
				ID:    peerID,
				Addrs: []multiaddr.Multiaddr{conn.RemoteMultiaddr()},
			}

			// Add to peer list
			n.peersMutex.Lock()
			defer n.peersMutex.Unlock()
			// Check if peer is already added
			for _, p := range n.peers {
				if p.ID == peerID {
					return
				}
			}

			if peerID == n.host.ID() {
				return // dont connect to self
			}

			n.peers = append(n.peers, &addrInfo)
			slog.Info("Peer added to list via Notify", "peerID", peerID, "hostPeerID", n.host.ID())
		},
	})
}

func (n *Network) Close() error {
	return n.host.Close()
}

func (n *Network) DiscoverPeers(ctx context.Context) {
	t := time.NewTicker(defaultPeerDiscoveryInternal)
	defer t.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			peerChan, err := n.routingDiscovery.FindPeers(ctx, rendezvous)
			if err != nil {
				slog.Warn("Failed to find peers", "err", err)
				continue
			}

			for peerInfo := range peerChan {
				if peerInfo.ID == n.host.ID() {
					continue // Don't connect to self
				}

				slog.Info("Found peer", "peer", peerInfo.ID)
				if err := n.host.Connect(ctx, peerInfo); err != nil {
					slog.Error("Failed to connect to peer", "peerID", peerInfo.ID, "err", err)
				} else {
					n.peersMutex.Lock()
					n.peers = append(n.peers, &peerInfo)
					n.peersMutex.Unlock()
					slog.Info("Connected to peer", "peerID", peerInfo.ID)
				}
			}
		}
	}
}

// Publish a message to the network
func Publish[T any](ctx context.Context, n *Network, topicName string, msg T) error {
	if n.topics[topicName] == nil {
		return errors.New("topic not registered")
	}

	data, err := json.Marshal(msg)
	if err != nil {
		return err
	}

	if err := n.topics[topicName].Publish(ctx, data); err != nil {
		return err
	}

	slog.Info("message published", "topic", topicName, "msg", msg, "peers", n.topics[topicName].ListPeers())

	return nil
}

func JoinTopic[T any](_ context.Context, n *Network, topicName string, topicHandler topicHandlerFunc[T]) error {
	topic, err := n.ps.Join(topicName)
	if err != nil {
		return err
	}

	n.topics[topicName] = topic
	n.topicHandlers[topicName] = topicHandler

	return nil
}

func SubscribeToTopic[T any](ctx context.Context, n *Network, topicName string) error {
	if n.topics[topicName] == nil || n.topicHandlers[topicName] == nil {
		return errors.New("Topic not found")
	}

	sub, err := n.topics[topicName].Subscribe()
	if err != nil {
		return err
	}

	t := time.NewTicker(defaultPeerDiscoveryInternal)
	for {
		select {
		case <-ctx.Done():
			return nil
		case <-t.C:
			msg, err := sub.Next(ctx)
			if err != nil {
				continue
			}

			// dont accept messages from self
			if n.host.ID() == msg.ReceivedFrom {
				continue
			}

			n.receivedMessages = n.receivedMessages + 1

			var data T
			if err := json.Unmarshal(msg.Data, &data); err != nil {
				continue
			}

			slog.Info("p2p network message found", "from", msg.ReceivedFrom, "data", data)

			handler := n.topicHandlers[topicName].(topicHandlerFunc[T])
			if err := handler(ctx, data); err != nil {
				slog.Error("error handling topic message", "err", err)
			}
		}
	}
}

func bootstrapDHT(ctx context.Context, n *Network, addr string, host host.Host, dht *kaddht.IpfsDHT) error {
	if addr == "" {
		return nil // this is the bootstrap node
	}

	ma, err := multiaddr.NewMultiaddr(addr)
	if err != nil {
		slog.Error("Invalid bootstrap address", "addr", addr, "err", err)
		return err
	}

	peerInfo, err := peer.AddrInfoFromP2pAddr(ma)
	if err != nil {
		slog.Error("invalid peerInfo", "addr", addr, "err", err)
		return err
	}

	if err := host.Connect(ctx, *peerInfo); err != nil {
		slog.Error("unable to connect to bootstrap peer", "peerID", peerInfo.ID, "err", err)
	} else {
		n.peersMutex.Lock()
		// Check if peer is already added
		for _, p := range n.peers {
			if p.ID == peerInfo.ID {
				return nil
			}
		}

		if peerInfo.ID == n.host.ID() {
			return nil
		}

		n.peers = append(n.peers, peerInfo)

		defer n.peersMutex.Unlock()
		slog.Info("successfully connected to peer", "peerID", peerInfo.ID, "hostPeerID", host.ID())
	}

	// Bootstrap the DHT
	return dht.Bootstrap(ctx)
}
