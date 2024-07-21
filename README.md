# Contour - Gatewayapi

Implements [Contour](https://projectcontour.io) ingress controller featuring [Gateway API](https://gateway-api.sigs.k8s.io/) 

EXPERIMENTAL

Scope:
- [ ] deploy [Contour](https://projectcontour.io) controller (by a helm chart?)
- [ ] deploy [Gateway API](https://gateway-api.sigs.k8s.io/)
- [ ] share common endpoint for [HTTPRoute](https://gateway-api.sigs.k8s.io/api-types/httproute/) and [TLSRoute](https://gateway-api.sigs.k8s.io/reference/spec/#gateway.networking.k8s.io/v1alpha2.TLSRoute)
- [ ] have proper tests

Deploy [dynamically provisioned](https://projectcontour.io/docs/1.29/guides/gateway-api/#option-2-dynamically-provisioned)

# Links
- https://projectcontour.io/docs/1.29/config/gateway-api/
- https://github.com/projectcontour/contour - upstream 
- https://projectcontour.io/docs/1.29/config/api/ - contour api reference