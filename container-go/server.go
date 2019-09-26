package main

import (
	"bytes"
	"context"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"hash/crc32"
	"log"
	"net/http"
	"net/url"
	"os"

	"cloud.google.com/go/storage"
	"github.com/gorilla/mux"
	"github.com/mr-tron/base58"
)

type errorResponse struct {
	Message string `json:"message"`
}

type successResponse struct {
	ShortenedURL string `json:"shortened_url"`
	Message      string `json:"message"`
}

func main() {
	router := mux.NewRouter()
	router.HandleFunc("/s", shortenHandler).Methods(http.MethodGet, http.MethodOptions)
	router.HandleFunc("/slack", slackHandler).Methods(http.MethodPost, http.MethodOptions)
	router.HandleFunc("/{id:[\\w-]+}", lengthenHandler).Methods(http.MethodGet, http.MethodOptions)
	router.PathPrefix("/").Handler(http.FileServer(http.Dir("./public/")))
	router.Use(mux.CORSMethodMiddleware(router))
	http.Handle("/", router)
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%s", os.Getenv("PORT")), nil))
}

func shortenHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Content-Type", "application/json")
	if r.Method == http.MethodOptions {
		return
	}
	parameters, ok := r.URL.Query()["url"]
	if !ok || len(parameters[0]) < 1 {
		w.WriteHeader(http.StatusBadRequest)
		w.Write(respondError("no url to shorten provided!"))
		return
	}
	longURL := parameters[0]
	uri, err := url.Parse(longURL)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		w.Write(respondError("unable to parse URI. was it encoded?"))
		return
	}
	if uri.Scheme != "https" && uri.Scheme != "http" {
		w.WriteHeader(http.StatusBadRequest)
		w.Write(respondError("provided input is not a HTTP/HTTPS URL!"))
		return
	}

	custom := ""
	parameters, ok = r.URL.Query()["customname"]
	if ok {
		custom = parameters[0]
	}

	shortURL, err := shortenURL(longURL, custom)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write(respondError("unable to access GCS!"))
		return
	}
	w.Write(respondSuccess(shortURL, "url shortened!"))
}

func slackHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	if r.Method == http.MethodOptions {
		return
	}

	parameters, ok := r.URL.Query()["text"]
	if !ok || len(parameters[0]) < 1 {
		w.WriteHeader(http.StatusBadRequest)
		w.Write(respondError("no url to shorten provided!"))
		return
	}
	longURL := parameters[0]
	uri, err := url.Parse(longURL)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		w.Write(respondError("unable to parse URI. was it encoded?"))
		return
	}
	if uri.Scheme != "https" && uri.Scheme != "http" {
		w.WriteHeader(http.StatusBadRequest)
		w.Write(respondError("provided input is not a HTTP/HTTPS URL!"))
		return
	}

	custom := ""
	parameters, ok = r.URL.Query()["customname"]
	if ok {
		custom = parameters[0]
	}

	shortURL, err := shortenURL(longURL, custom)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write(respondError("unable to access GCS!"))
		return
	}
	w.Write(respondSuccess(shortURL, "url shortened!"))
}

func lengthenHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	if r.Method == http.MethodOptions {
		return
	}
	short := mux.Vars(r)["id"]
	longURL, err := lengthenURL(short)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		w.Write(respondError("unable to find URL!"))
		return
	}
	w.Header().Set("Location", longURL)
	w.WriteHeader(http.StatusMovedPermanently)
}

func shortenURL(long string, code string) (string, error) {
	if code == "" {
		code = generateShortCode(long)
	}

	err := gcsWrite(code, long)
	if err != nil {
		return "", err
	}

	return fmt.Sprintf("https://%s/%s", os.Getenv("DOMAIN"), code), nil
}

func lengthenURL(short string) (string, error) {
	return gcsRead(short)
}

func gcsWrite(short string, url string) error {
	ctx := context.Background()

	client, err := storage.NewClient(ctx)
	if err != nil {
		return err
	}

	bucket := client.Bucket(os.Getenv("BUCKET"))
	object := bucket.Object(short)
	writer := object.NewWriter(ctx)

	_, err = fmt.Fprintf(writer, url)
	if err != nil {
		return err
	}

	err = writer.Close()
	if err != nil {
		return err
	}

	err = client.Close()
	if err != nil {
		return err
	}

	return nil
}

func gcsRead(short string) (string, error) {
	ctx := context.Background()
	client, err := storage.NewClient(ctx)
	if err != nil {
		return "", err
	}

	bucket := client.Bucket(os.Getenv("BUCKET"))
	object := bucket.Object(short)

	reader, err := object.NewReader(ctx)
	if err != nil {
		return "", err
	}

	buffer := new(bytes.Buffer)
	buffer.ReadFrom(reader)

	err = reader.Close()
	if err != nil {
		return "", err
	}

	err = client.Close()
	if err != nil {
		return "", err
	}

	return buffer.String(), nil
}

func generateShortCode(url string) string {
	crc32 := crc32.ChecksumIEEE([]byte(url))
	num := make([]byte, 4)
	binary.LittleEndian.PutUint32(num, crc32)
	code := base58.Encode(num)
	return code
}

func respondError(message string) []byte {
	marshalled, err := json.Marshal(errorResponse{message})
	if err != nil {
		log.Println(err)
	}
	return marshalled
}

func respondSuccess(url string, message string) []byte {
	marshalled, err := json.Marshal(successResponse{url, message})
	if err != nil {
		log.Println(err)
	}
	return marshalled
}
