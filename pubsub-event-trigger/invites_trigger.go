package triggers

import (
	"context"
	"log"
)

type PubSubMessage struct {
	Data []byte `json:"data"`
}

func RegisterInvite(ctx context.Context, m PubSubMessage) error {
	message := string(m.Data)
	if message == "" {
		log.Printf("Empty message: No message data was recieved by the webhook")
	}
	log.Printf("Recieved: The message recieved from Pub/Sub topic, %s!", message)
	return nil
}
