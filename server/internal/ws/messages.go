package ws

import "encoding/json"

const (
	MessageTypePatch = "patch"
	MessageTypeAck   = "ack"
	MessageTypeError = "error"
)

type PatchMessage struct {
	Type      string  `json:"type"`
	RequestID string  `json:"requestId"`
	Content   string  `json:"content"`
	Title     *string `json:"title,omitempty"`
	IsPinned  *bool   `json:"isPinned,omitempty"`
	Flush     bool    `json:"flush,omitempty"`
}

type AckMessage struct {
	Type      string `json:"type"`
	RequestID string `json:"requestId"`
	SavedAt   string `json:"savedAt"`
}

type ErrorMessage struct {
	Type      string `json:"type"`
	RequestID string `json:"requestId,omitempty"`
	Message   string `json:"message"`
}

func DecodePatchMessage(payload []byte) (PatchMessage, error) {
	var message PatchMessage
	err := json.Unmarshal(payload, &message)
	return message, err
}
