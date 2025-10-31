package main

import (
	"context"
	"flag"
	"log"
	"os"
	"time"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
)

// PodSelector defines configuration for selecting and monitoring stuck pods
type PodSelector struct {
	Namespace         string
	LabelSelector     string
	InitContainerName string // Only support init container for now
	StuckThresholdMin int
}

// Configuration for stuck pod detection
var podSelectors = []PodSelector{
	{
		Namespace:         "kube-system",
		LabelSelector:     "component=kube-proxy",
		InitContainerName: "kube-proxy-bootstrap",
		StuckThresholdMin: 2,
	},
	{
		Namespace:         "kube-system",
		LabelSelector:     "k8s-app=azure-cns",
		InitContainerName: "cni-installer",
		StuckThresholdMin: 2,
	},

	// Add more selectors here as needed
}

func main() {
	dryRun := flag.Bool("dry-run", true, "Dry run mode - only log what would be deleted. Default is true for safety")
	flag.Parse()

	log.Printf("Starting stuck pod killer (dry-run: %v)", *dryRun)

	// Create Kubernetes config
	config, err := getKubernetesConfig()
	if err != nil {
		log.Fatalf("Failed to create kubernetes config: %v", err)
	}

	// Create clientset
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		log.Fatalf("Failed to create kubernetes client: %v", err)
	}

	ctx := context.Background()

	totalStuckPods := 0
	totalDeletedPods := 0

	// Process each selector configuration
	for _, selector := range podSelectors {
		log.Printf("Processing selector: namespace=%s, labelSelector=%s, container=%s, threshold=%dm",
			selector.Namespace, selector.LabelSelector, selector.InitContainerName, selector.StuckThresholdMin)

		// List pods with specific label selector
		pods, err := clientset.CoreV1().Pods(selector.Namespace).List(ctx, metav1.ListOptions{
			LabelSelector: selector.LabelSelector,
		})
		if err != nil {
			log.Printf("ERROR: Failed to list pods in namespace %s: %v", selector.Namespace, err)
			continue
		}

		log.Printf("Found %d pods with labelSelector %s in namespace %s", len(pods.Items), selector.LabelSelector, selector.Namespace)

		stuckPods := 0
		deletedPods := 0

		for _, pod := range pods.Items {
			if isStuckInInit(&pod, &selector) {
				stuckPods++
				log.Printf("Pod %s/%s is stuck in init phase for more than %d minutes",
					pod.Namespace, pod.Name, selector.StuckThresholdMin)

				if !*dryRun {
					log.Printf("Force deleting pod: %s/%s", pod.Namespace, pod.Name)
					gracePeriodSeconds := int64(0)
					err := clientset.CoreV1().Pods(selector.Namespace).Delete(
						ctx,
						pod.Name,
						metav1.DeleteOptions{
							GracePeriodSeconds: &gracePeriodSeconds,
						},
					)
					if err != nil {
						log.Printf("ERROR: Failed to delete pod %s/%s: %v", pod.Namespace, pod.Name, err)
					} else {
						deletedPods++
						log.Printf("Successfully deleted pod: %s/%s", pod.Namespace, pod.Name)
					}
				} else {
					log.Printf("[DRY-RUN] Would delete pod: %s/%s", pod.Namespace, pod.Name)
				}
			}
		}

		log.Printf("Selector summary: Found %d stuck pods, deleted %d pods", stuckPods, deletedPods)
		totalStuckPods += stuckPods
		totalDeletedPods += deletedPods
	}

	log.Printf("Overall summary: Found %d stuck pods, deleted %d pods", totalStuckPods, totalDeletedPods)

	if totalStuckPods > 0 && !*dryRun {
		os.Exit(0)
	}

	if totalStuckPods == 0 {
		log.Println("No stuck pods found - all healthy")
	}
}

func isStuckInInit(pod *corev1.Pod, selector *PodSelector) bool {
	// Check if pod is in Pending phase
	if pod.Status.Phase != "Pending" {
		// Noisy log
		// log.Printf("Pod %s/%s is not in Pending phase (current: %s), skipping", pod.Namespace, pod.Name, pod.Status.Phase)
		return false
	}

	// Check if the specific init container is stuck
	hasTargetInitContainer := false
	initContainerStuck := false

	for _, initStatus := range pod.Status.InitContainerStatuses {

		if initStatus.Name == selector.InitContainerName {
			hasTargetInitContainer = true

			// Check if it's running (stuck) and not ready
			if initStatus.State.Running != nil && !initStatus.Ready {
				startTime := initStatus.State.Running.StartedAt.Time
				runningDuration := time.Since(startTime)

				if runningDuration > time.Duration(selector.StuckThresholdMin)*time.Minute {
					initContainerStuck = true
					break
				}
			}
		}
	}

	if !hasTargetInitContainer {
		log.Printf("Pod %s/%s: target init container %s not found", pod.Namespace, pod.Name, selector.InitContainerName)
		return false
	}

	if !initContainerStuck {
		log.Printf("Pod %s/%s: init container %s is not stuck, either not running or ready", pod.Namespace, pod.Name, selector.InitContainerName)
		return false
	}

	// Additional safety check: verify pod has the Initialized=False condition
	hasInitializedFalse := false
	for _, condition := range pod.Status.Conditions {
		if condition.Type == "Initialized" && condition.Status == "False" {
			hasInitializedFalse = true
			break
		}
	}

	if !hasInitializedFalse {
		log.Printf("Pod %s/%s: does not have Initialized=False condition", pod.Namespace, pod.Name)
	}

	log.Printf("Pod %s/%s is stuck in init phase for more than %d minutes", pod.Namespace, pod.Name, selector.StuckThresholdMin)
	return true
}

// getKubernetesConfig creates a Kubernetes config for both in-cluster and local development
func getKubernetesConfig() (*rest.Config, error) {
	// Try in-cluster config first (when running inside a pod)
	if config, err := rest.InClusterConfig(); err == nil {
		log.Println("Using in-cluster config")
		return config, nil
	}

	// Fall back to kubeconfig file for local development
	kubeconfig := clientcmd.NewDefaultClientConfigLoadingRules().GetDefaultFilename()
	log.Printf("Using kubeconfig: %s", kubeconfig)
	return clientcmd.BuildConfigFromFlags("", kubeconfig)
}
