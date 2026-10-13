{{- define "taskboard.labels" -}}
app.kubernetes.io/name: taskboard
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}
{{- define "taskboard.secretName" -}}{{ .Release.Name }}-db{{- end }}
{{- define "taskboard.dbHost" -}}{{ .Release.Name }}-postgres{{- end }}
{{- define "taskboard.backendName" -}}{{ .Release.Name }}-backend{{- end }}
