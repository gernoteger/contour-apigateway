{{/*
hosts 
*/}}
{{- define "homassistant-top.labels" -}}
helm.sh/chart: {{ include "homassistant-top.chart" . }}
{{ include "homassistant-top.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
