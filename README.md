# Gatewayapi Showcase - Using Contour?

Implements [Contour](https://projectcontour.io) ingress controller featuring [Gateway API](https://gateway-api.sigs.k8s.io/) 

EXPERIMENTAL

Try to implement this usecase:

1. I have a set of services, Urls following a naming convention: <service>.<basUrl>
2. all services have a common ip/dns name
3. some use edge termination, some TLS passthrough
4. both https and http shall be available
5. The gateway internal design shall leak as little as possible into the applications' implementations.
6. Gateway API shall be used

AddOn: maybe use other controllers than contour!

Scope:
- [ ] deploy [Contour](https://projectcontour.io) controller (by a helm chart?)
- [ ] deploy [Gateway API](https://gateway-api.sigs.k8s.io/)
- [ ] share common endpoint for [HTTPRoute](https://gateway-api.sigs.k8s.io/api-types/httproute/) and [TLSRoute](https://gateway-api.sigs.k8s.io/reference/spec/#gateway.networking.k8s.io/v1alpha2.TLSRoute)
- [ ] enable HTTPProxy and Ingress for legacy
- [ ] have proper tests

Deploy [dynamically provisioned](https://projectcontour.io/docs/1.29/guides/gateway-api/#option-2-dynamically-provisioned)

# Design

Assume those services.

- echo-edge-1.example.com - edge termination
- echo-edge-2.example.com - edge termination
- echo-passthrough1.example.com  - passhtrough termination
- echo-passthrough2.example.com  - passhtrough termination

Idea1, produces 1 extra network hop for https edge termination
```mermaid
flowchart TD
    
    subgraph net
        R1[Request http://*.example.com]
        R2[Request https://*.example.com]
    end 

    subgraph edge
        R1==>LE1

%% positioning
        R1~~~GWEdge
        R2~~~GWEdge

        GWEdge(["Edge Gateway"])

        GWEdge-->LE1[listener 80 http];
        GWEdge-->LE2[listener 443 tls];
        R2==>LE2


        LE1-->|80 http|HTTPRoute1[HTTPRoute echo-edge1.example.com];
        LE1-->|80 http|HTTPRoute2[HTTPRoute echo-passthrough1.example.com];
        LE1-->|80 http|HTTPRoute3[...];
        LE2-->|443 tls|TLSRouteEdge["TLSRoute *.example.com"];
        LE2-->TLSRoute1["TLSRoute echo-passthrough1.example.com"];
        LE2-->TLSRoute2["TLSRoute echo-passthrough2.example.com"];
        
    end
    subgraph internal
        GWInternal(["Internal GW - Service ClusterIP"])

        TLSRouteEdge ~~~ GWInternal
        TLSRouteEdge ==> LI1
        GWInternal-->LI1[listener 443 https];
        LI1-->|443 https|HTTPRouteHttps1["https://echo-edge1.example.com"];
        LI1-->|443 https|HTTPRouteHttps2["https://echo-edge2.example.com"];
    end
```

> [!TIP]
> Create a helm chart for the use case + one for the GW implementations

# Missing
- GRPCRoute
- Observability
# Links
- https://projectcontour.io/docs/1.29/config/gateway-api/
- https://github.com/projectcontour/contour - upstream 
- https://projectcontour.io/docs/1.29/config/api/ - contour api reference
