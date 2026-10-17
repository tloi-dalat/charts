{{- define "app.name" -}}
{{- default .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "app.labels" -}}
{{ include "app.selectorLabels" . }}
app.kubernetes.io/part-of: {{ .Release.Namespace }}
app.kubernetes.io/version: {{ .Values.image.tag | trunc 63 | trimSuffix "-" | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{- define "app.image" -}}
{{- $tag := required "image.tag is required" .Values.image.tag -}}
{{- $repo := required "image.repository is required" .Values.image.repository -}}
{{- if .Values.image.digest -}}
{{ $repo }}:{{ $tag }}@{{ .Values.image.digest }}
{{- else -}}
{{ $repo }}:{{ $tag }}
{{- end -}}
{{- end -}}

{{- define "app.env" -}}
{{- range $name, $value := .Values.env }}
- name: {{ $name }}
{{- if kindIs "map" $value }}
{{ toYaml $value | indent 2 }}
{{- else }}
  value: {{ $value | toString | quote }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "app.podCommon" -}}
automountServiceAccountToken: {{ .Values.automountServiceAccountToken }}
enableServiceLinks: false
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
{{ toYaml . }}
{{- end }}
{{- with .Values.podSecurityContext }}
securityContext:
{{ toYaml . | indent 2 }}
{{- end }}
{{- with .Values.nodeSelector }}
nodeSelector:
{{ toYaml . | indent 2 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
{{ toYaml . }}
{{- end }}
{{- with .Values.affinity }}
affinity:
{{ toYaml . | indent 2 }}
{{- end }}
{{- end -}}

{{- define "app.containerCommon" -}}
image: {{ include "app.image" . | quote }}
imagePullPolicy: {{ .Values.image.pullPolicy }}
{{- with .Values.env }}
env:
{{- include "app.env" $ }}
{{- end }}
{{- with .Values.envFrom }}
envFrom:
{{ toYaml . }}
{{- end }}
{{- with .Values.securityContext }}
securityContext:
{{ toYaml . | indent 2 }}
{{- end }}
{{- end -}}
