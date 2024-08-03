{{/*
Expand the name of the chart.
*/}}
{{- define "gateways.namespace" -}}
{{- default "ingress1" .Values.ingress.gateway.namespace }}
{{- end }}
