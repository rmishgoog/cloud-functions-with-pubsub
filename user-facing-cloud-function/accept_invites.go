package invites

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"

	"cloud.google.com/go/pubsub"
)

var projectID = os.Getenv("GOOGLE_CLOUD_PROJECT")
var topicID = os.Getenv("PUBSUB_TOPIC_ID")
var client *pubsub.Client

func init() {
	var err error
	client, err = pubsub.NewClient(context.Background(), projectID)
	if err != nil {
		log.Fatalf("Error:pubsub.NewClient: %v", err)
	}
}

func AcceptInvites(writer http.ResponseWriter, request *http.Request) {
	var responder struct {
		Name  string `json:"name"`
		Voted string `json:"vote"`
	}
	if err := json.NewDecoder(request.Body).Decode(&responder); err != nil {
		log.Println("json.NewDecoder: %v", err)
		http.Error(writer, "Error:parsing the request, please validate the request body", http.StatusBadRequest)
		return
	}
	if responder.Name == "" || responder.Voted == "" {
		err_msg := "Error:missing data"
		log.Println("json.NewDecoder: %v", err_msg)
		http.Error(writer, "Error:parsing the request, missing the required data", http.StatusBadRequest)
		return
	}
	payload, _ := json.Marshal(responder)
	message := &pubsub.Message{
		Data: []byte(payload),
	}
	_, err := client.Topic(topicID).Publish(request.Context(), message).Get(request.Context())
	if err != nil {
		log.Printf("topic(%s).Publish.Get: %v", topicID, err)
		http.Error(writer, "Error: publishing message", http.StatusInternalServerError)
		return
	}
	fmt.Fprintf(writer, "Hello, %s!, we have recieved your vote.", responder.Name)
}
