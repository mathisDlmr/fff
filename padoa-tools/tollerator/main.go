package main

import (
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"

	admissionv1 "k8s.io/api/admission/v1"
	v1 "k8s.io/api/admission/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/serializer"
)

var (
	logg   = log.New(os.Stdout, "", log.LstdFlags)
	codecs = serializer.NewCodecFactory(runtime.NewScheme())
)

func admissionReviewFromRequest(r *http.Request, deserializer runtime.Decoder) (*admissionv1.AdmissionReview, error) {
	// Validate that the incoming content type is correct.
	if r.Header.Get("Content-Type") != "application/json" {
		return nil, fmt.Errorf("expected application/json content-type")
	}

	// Get the body data, which will be the AdmissionReview
	// content for the request.
	var body []byte
	if r.Body != nil {
		requestData, err := ioutil.ReadAll(r.Body)
		if err != nil {
			return nil, err
		}
		body = requestData
	}

	// Decode the request body into
	admissionReviewRequest := &admissionv1.AdmissionReview{}
	if _, _, err := deserializer.Decode(body, nil, admissionReviewRequest); err != nil {
		return nil, err
	}

	return admissionReviewRequest, nil
}

func liveProbe(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(200)
	w.Write([]byte("ok"))
}

func mutatePod(w http.ResponseWriter, r *http.Request) {
	logg.Println("Received request to mutate pod")
	deserializer := codecs.UniversalDeserializer()

	// Parse the AdmissionReview from the http request.
	admissionReviewRequest, err := admissionReviewFromRequest(r, deserializer)
	if err != nil {
		msg := fmt.Sprintf("error getting admission review from request: %v", err)
		logg.Printf(msg)
		w.WriteHeader(400)
		w.Write([]byte(msg))
		return
	}

	// Do server-side validation that we are only dealing with a pod resource. This
	// should also be part of the MutatingWebhookConfiguration in the cluster, but
	// we should verify here before continuing.
	podResource := metav1.GroupVersionResource{Group: "", Version: "v1", Resource: "pods"}
	if admissionReviewRequest.Request.Resource != podResource {
		msg := fmt.Sprintf("did not receive pod, got %s", admissionReviewRequest.Request.Resource.Resource)
		logg.Printf(msg)
		w.WriteHeader(400)
		w.Write([]byte(msg))
		return
	}

	// Decode the pod from the AdmissionReview.
	rawRequest := admissionReviewRequest.Request.Object.Raw
	pod := corev1.Pod{}
	if _, _, err := deserializer.Decode(rawRequest, nil, &pod); err != nil {
		msg := fmt.Sprintf("error decoding raw pod: %v", err)
		logg.Printf(msg)
		w.WriteHeader(500)
		w.Write([]byte(msg))
		return
	}

	// Create a response that will add a label to the pod if it does
	// not already have a label with the key of "hello". In this case
	// it does not matter what the value is, as long as the key exists.
	admissionResponse := &admissionv1.AdmissionResponse{}
	var patch string
	patchType := v1.PatchTypeJSONPatch
	if _, ok := pod.Annotations["nospot"]; !ok {
		addToleration := true
		for _, toleration := range pod.Spec.Tolerations {
			if toleration.Key == "kubernetes.azure.com/scalesetpriority" && toleration.Value == "spot" {
				addToleration = false
			}
		}
		if addToleration {
			patch = `[{"op":"add","path":"/spec/tolerations/-","value":{"key":"kubernetes.azure.com/scalesetpriority","operator":"Equal","value":"spot","effect":"NoSchedule"}}]`
		}
	}

	admissionResponse.Allowed = true
	if patch != "" {
		admissionResponse.PatchType = &patchType
		admissionResponse.Patch = []byte(patch)
	}

	// Construct the response, which is just another AdmissionReview.
	var admissionReviewResponse admissionv1.AdmissionReview
	admissionReviewResponse.Response = admissionResponse
	admissionReviewResponse.SetGroupVersionKind(admissionReviewRequest.GroupVersionKind())
	admissionReviewResponse.Response.UID = admissionReviewRequest.Request.UID

	resp, err := json.Marshal(admissionReviewResponse)
	if err != nil {
		msg := fmt.Sprintf("error marshalling response json: %v", err)
		logg.Printf(msg)
		w.WriteHeader(500)
		w.Write([]byte(msg))
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write(resp)
}

func main() {
	cert, err := tls.LoadX509KeyPair(os.Getenv("TLS_CERT_FILE"), os.Getenv("TLS_PRIVATE_KEY_FILE"))
	if err != nil {
		log.Fatalf("Failed to load cert: %v", err)
	}

	logg.Println("Starting webhook server")
	http.HandleFunc("/mutate", mutatePod)
	http.HandleFunc("/live", liveProbe)
	server := http.Server{
		Addr: fmt.Sprintf(":%d", 443),
		TLSConfig: &tls.Config{
			Certificates:             []tls.Certificate{cert},
			MinVersion:               tls.VersionTLS13,
			PreferServerCipherSuites: true,
		},
		ErrorLog: logg,
	}

	if err := server.ListenAndServeTLS("", ""); err != nil {
		panic(err)
	}
}
