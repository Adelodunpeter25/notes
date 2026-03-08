package ws

import (
	"encoding/json"
	"log"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"notes/server/internal/schemas"
)

const (
	writeWait    = 10 * time.Second
	pongWait     = 60 * time.Second
	pingPeriod   = (pongWait * 9) / 10
	saveDebounce = 800 * time.Millisecond
)

type Client struct {
	connection *websocket.Conn
	hub        *Hub
	service    RealtimeSaver
	userID     string
	noteID     string
	send       chan []byte
	closeOnce  sync.Once
}

type RealtimeSaver interface {
	ApplyPatch(userID, noteID string, patch PatchMessage) (schemas.NoteResponse, error)
}

func NewClient(connection *websocket.Conn, hub *Hub, service RealtimeSaver, userID, noteID string) *Client {
	return &Client{
		connection: connection,
		hub:        hub,
		service:    service,
		userID:     userID,
		noteID:     noteID,
		send:       make(chan []byte, 16),
	}
}

func (client *Client) Start() {
	client.hub.Register(client)
	go client.writePump()
	client.readPump()
}

func (client *Client) readPump() {
	defer client.shutdown()

	_ = client.connection.SetReadDeadline(time.Now().Add(pongWait))
	client.connection.SetPongHandler(func(string) error {
		return client.connection.SetReadDeadline(time.Now().Add(pongWait))
	})

	var latestPatch *PatchMessage

	timer := time.NewTimer(24 * time.Hour)
	defer timer.Stop()
	resetTimer := func(duration time.Duration) {
		if !timer.Stop() {
			select {
			case <-timer.C:
			default:
			}
		}
		timer.Reset(duration)
	}

	resetTimer(24 * time.Hour)

	for {
		select {
		case <-timer.C:
			if latestPatch != nil {
				client.flushPatch(*latestPatch)
				latestPatch = nil
			}
			resetTimer(24 * time.Hour)
		default:
		}

		_, payload, err := client.connection.ReadMessage()
		if err != nil {
			if latestPatch != nil {
				client.flushPatch(*latestPatch)
			}
			return
		}

		message, err := DecodePatchMessage(payload)
		if err != nil {
			client.sendError("", "invalid message payload")
			continue
		}
		if message.Type != MessageTypePatch {
			client.sendError(message.RequestID, "unsupported message type")
			continue
		}

		latestPatch = &message

		client.hub.Broadcast(client.noteID, client, payload)

		if message.Flush {
			client.flushPatch(message)
			latestPatch = nil
			resetTimer(24 * time.Hour)
			continue
		}

		resetTimer(saveDebounce)
	}
}

func (client *Client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer ticker.Stop()
	defer client.shutdown()

	for {
		select {
		case message, ok := <-client.send:
			_ = client.connection.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				_ = client.connection.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			if err := client.connection.WriteMessage(websocket.TextMessage, message); err != nil {
				return
			}
		case <-ticker.C:
			_ = client.connection.SetWriteDeadline(time.Now().Add(writeWait))
			if err := client.connection.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

func (client *Client) shutdown() {
	client.closeOnce.Do(func() {
		client.hub.Unregister(client)
		close(client.send)
		_ = client.connection.Close()
	})
}

func (client *Client) flushPatch(message PatchMessage) {
	response, err := client.service.ApplyPatch(client.userID, client.noteID, message)
	if err != nil {
		log.Printf("ws patch save failed for note %s: %v", client.noteID, err)
		client.sendError(message.RequestID, "failed to save note")
		return
	}

	ack := AckMessage{
		Type:      MessageTypeAck,
		RequestID: message.RequestID,
		SavedAt:   response.UpdatedAt.UTC().Format(time.RFC3339Nano),
	}
	data, err := json.Marshal(ack)
	if err != nil {
		return
	}

	select {
	case client.send <- data:
	default:
	}
}

func (client *Client) sendError(requestID, message string) {
	payload, err := json.Marshal(ErrorMessage{
		Type:      MessageTypeError,
		RequestID: requestID,
		Message:   message,
	})
	if err != nil {
		return
	}

	select {
	case client.send <- payload:
	default:
	}
}
