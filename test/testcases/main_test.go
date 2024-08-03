package main

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
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
	// gateway API
	//"github.com/gatwayapi/client"
	//sigs.k8s.io/controller-runtime/pkg/client"
	//"sigs.k8s.io/controller-runtime/pkg/client"

	// sigs.k8s.io/gateway-api/pkg/client/clientset/versioned
	gatewayapi_client "sigs.k8s.io/gateway-api/pkg/client/clientset/versioned"
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
	ClientCertificate map[string]string `json:"clientCertificate,omitempty"`
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

func gatewayAddress(namespace, gatewayName string) (string, error) {

	ctx := context.TODO()

	config, err := clientConfig()
	if err != nil {
		return "", err
	}

	c2, err := gatewayapi_client.NewForConfig(config)
	if err != nil {
		return "", err
	}
	gw, err := c2.GatewayV1().Gateways(namespace).Get(ctx, gatewayName, metav1.GetOptions{})

	if err != nil {
		return "", err
	}
	ip := gw.Status.Addresses[0].Value

	return ip, nil
}

// func contourServiceIP(namespace, loadbalancerServiceName string) (string, error) {

// 	svcHost := os.Getenv("TARGET_SERVICE_HOST")
// 	if svcHost != "" {
// 		return svcHost, nil
// 	}
// 	clientset, err := clientSet()
// 	if err != nil {
// 		return "", err
// 	}

// 	ctx := context.TODO()

// 	lbService, err := clientset.CoreV1().Services(namespace).Get(ctx, loadbalancerServiceName, metav1.GetOptions{})
// 	if err != nil {
// 		return "", err
// 	}

// 	svc_ingress := lbService.Status.LoadBalancer.Ingress[0]
// 	// svcIP = svc_ingress.IP
// 	// svcPorts := lbService.Spec.Ports

// 	return svc_ingress.IP, nil
// }

func getEchoResponse(connectionHost string, testUrl string) (*Echo, error) {
	dialer := &net.Dialer{
		Timeout:   2 * time.Minute,
		KeepAlive: 30 * time.Second,
		DualStack: true,
	}

	c := http.Client{
		Timeout: 2 * time.Second,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
			DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
				addr = connectionHost + addr[strings.LastIndex(addr, ":"):]
				return dialer.DialContext(ctx, network, addr)
			},
		},
	}

	req, err := http.NewRequest("GET", testUrl, nil)
	if err != nil {
		return nil, err
	}

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

func assertGatewayAddress(t *testing.T) (string, error) {
	namespace := "ingress" //TODO: get from k8s??
	svcIP, err := gatewayAddress(namespace, "edge")
	assert.NoError(t, err)
	assert.Regexp(t, "[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+", svcIP)

	return svcIP, err
}

func assertEchoResponse(t *testing.T, svcIP string, url string) (Echo, error) {

	echo, err := getEchoResponse(svcIP, url)
	assert.NoError(t, err)
	if assert.NotEmpty(t, echo) {
		assert.Regexp(t, "^echo-", echo.Os.Hostname)
	}

	return *echo, err
}

func TestGetHttpProxyEcho(t *testing.T) {
	t.Skip()

	svcIP, err := assertGatewayAddress(t)
	if err != nil {
		assertEchoResponse(t, svcIP, "http://echo-proxy-http.example.com")
		assertEchoResponse(t, svcIP, "https://echo-proxy-http.example.com")
	}
}

func TestIngressEcho(t *testing.T) {
	t.Skip()

	svcIP, err := assertGatewayAddress(t)
	if err == nil {
		assertEchoResponse(t, svcIP, "https://echo-ingress-https.example.com")
		assertEchoResponse(t, svcIP, "http://echo-ingress-https.example.com")
	}

}

func TestHTTPRouteEcho(t *testing.T) {

	svcIP, err := assertGatewayAddress(t)
	if err == nil {
		assertEchoResponse(t, svcIP, "http://echo.example.com")
		assertEchoResponse(t, svcIP, "https://echo.example.com")
	}
}

func TestTLSRouteEcho(t *testing.T) {

	svcIP, err := assertGatewayAddress(t)
	if err == nil {
		echo, err := assertEchoResponse(t, svcIP, "https://echo-tls.example.com") // TODO: addd test for client certificate
		if err == nil {
			assert.Empty(t, echo.ClientCertificate)
		}
	}
}
