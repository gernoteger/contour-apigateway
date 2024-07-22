package main

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	restclient "k8s.io/client-go/rest"
	clienttools "k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/util/homedir"

	// kubeconfig "github.com/siderolabs/go-kubeconfig"

	//
	// Uncomment to load all auth plugins
	_ "k8s.io/client-go/plugin/pkg/client/auth"
	//
	// Or uncomment to load specific auth plugins
	// _ "k8s.io/client-go/plugin/pkg/client/auth/azure"
	// _ "k8s.io/client-go/plugin/pkg/client/auth/gcp"
	// _ "k8s.io/client-go/plugin/pkg/client/auth/oidc"
)

type Echo struct {
	Path     string
	Headers  map[string]string
	Method   string
	Body     string
	Cookies  map[string]string `json:"cookies,omitempty"`
	Fresh    bool
	Hostname string
	IP       string
	IPS      []string

	Protocol   string
	Query      map[string]string
	Subdomains []string

	Xhr bool
	Os  struct {
		Hostname string
	}

	Connection struct {
		Servername string
	}
	// TODO: client cert?
}

// return  client config
// automatically select if we are in cluster., or get from local configs
func clientConfig() (*restclient.Config, error) {

	config, err := restclient.InClusterConfig()
	if err == nil {
		return config, err
	}

	// use kubectl
	// see: https://github.com/kubernetes/client-go/blob/master/examples/out-of-cluster-client-configuration/main.go
	// kubeconfig := filepath.Join(homedir.HomeDir(), ".kube", "config")
	kubeconfig := os.Getenv("KUBECONFIG")
	if kubeconfig == "" {
		kubeconfig = filepath.Join(homedir.HomeDir(), ".kube", "config")
	}

	files := strings.Split(kubeconfig, ":") // TODO: os specific seperator
	//TODO: absolute paths!!
	return clienttools.NewNonInteractiveDeferredLoadingClientConfig(
		// &clienttools.ClientConfigLoadingRules{ExplicitPath: kubeconfigPath},
		&clienttools.ClientConfigLoadingRules{Precedence: files},
		&clienttools.ConfigOverrides{}).ClientConfig()
}

func clientSet() (*kubernetes.Clientset, error) {
	config, err := clientConfig()
	if err != nil {
		return nil, err
	}

	// create the clientset
	clientset, err := kubernetes.NewForConfig(config)

	return clientset, err
}

func contourServiceIP(namespace, loadbalancerServiceName string) (string, error) {

	svcHost := os.Getenv("TARGET_SERVICE_HOST")
	if svcHost != "" {
		return svcHost, nil
	}
	clientset, err := clientSet()
	if err != nil {
		return "", err
	}

	ctx := context.TODO()

	lbService, err := clientset.CoreV1().Services(namespace).Get(ctx, loadbalancerServiceName, metav1.GetOptions{})
	if err != nil {
		return "", err
	}

	svc_ingress := lbService.Status.LoadBalancer.Ingress[0]
	// svcIP = svc_ingress.IP
	// svcPorts := lbService.Spec.Ports

	return svc_ingress.IP, nil
}

func getEchoResponse(scheme, host string, hostname string) (*Echo, error) {
	url := url.URL{
		Scheme: scheme,
		Host:   hostname,
		// Path:     "foo",
		// RawQuery: "a=10",
	}

	// TODO: use https://github.com/golang/go/issues/22704#issuecomment-346537646
	// TODO: fix this
	dialer := &net.Dialer{
		Timeout:   30 * time.Second,
		KeepAlive: 30 * time.Second,
		DualStack: true,
	}

	c := http.Client{
		Timeout: 2 * time.Second,
		Transport: &http.Transport{
			DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
				// redirect all connections to 127.0.0.1
				addr = host + addr[strings.LastIndex(addr, ":"):]
				return dialer.DialContext(ctx, network, addr)
			},
		},
	}

	req, err := http.NewRequest("GET", url.String(), nil)
	if err != nil {
		return nil, err
	}

	// req.Host = hostname // set header  fails!

	resp, err := c.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, errors.New("404: not found")
	}

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	// bodyString := string(bodyBytes)
	// fmt.Println(bodyString)

	echo := Echo{}
	err = json.Unmarshal(bodyBytes, &echo)

	return &echo, err
}

func TestGetHttpEcho(t *testing.T) {

	namespace := "projectcontour" //TODO: get from k8s??

	svcIP, err := contourServiceIP(namespace, "contour-envoy") //"envoy-contour"

	assert.NoError(t, err)
	assert.Regexp(t, "[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+", svcIP)

	echo, err := getEchoResponse("http", svcIP, "echo-proxy-http.example.com:80")
	assert.NoError(t, err)
	assert.NotEmpty(t, echo)

	assert.Regexp(t, "^echo-", echo.Os.Hostname)
}
