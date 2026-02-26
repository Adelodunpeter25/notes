package ws

import "sync"

type Hub struct {
	mutex   sync.RWMutex
	clients map[string]map[*Client]struct{}
}

func NewHub() *Hub {
	return &Hub{
		clients: make(map[string]map[*Client]struct{}),
	}
}

func (hub *Hub) Register(client *Client) {
	hub.mutex.Lock()
	defer hub.mutex.Unlock()

	if _, ok := hub.clients[client.noteID]; !ok {
		hub.clients[client.noteID] = make(map[*Client]struct{})
	}

	hub.clients[client.noteID][client] = struct{}{}
}

func (hub *Hub) Unregister(client *Client) {
	hub.mutex.Lock()
	defer hub.mutex.Unlock()

	noteClients, ok := hub.clients[client.noteID]
	if !ok {
		return
	}

	delete(noteClients, client)
	if len(noteClients) == 0 {
		delete(hub.clients, client.noteID)
	}
}

func (hub *Hub) Broadcast(noteID string, sender *Client, payload []byte) {
	hub.mutex.RLock()
	defer hub.mutex.RUnlock()

	noteClients, ok := hub.clients[noteID]
	if !ok {
		return
	}

	for client := range noteClients {
		if client == sender {
			continue
		}
		select {
		case client.send <- payload:
		default:
		}
	}
}
