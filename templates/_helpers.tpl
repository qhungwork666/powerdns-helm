{{- define "powerdns-poweradmin.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "powerdns-poweradmin.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "powerdns-poweradmin.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end }}

{{- define "powerdns-poweradmin.labels" -}}
app.kubernetes.io/name: {{ include "powerdns-poweradmin.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end }}

{{- define "powerdns-poweradmin.selectorLabels" -}}
app.kubernetes.io/name: {{ include "powerdns-poweradmin.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "powerdns-poweradmin.pdnsName" -}}
{{ include "powerdns-poweradmin.fullname" . }}-powerdns
{{- end }}

{{- define "powerdns-poweradmin.pdnsApiName" -}}
{{ include "powerdns-poweradmin.fullname" . }}-powerdns-api
{{- end }}

{{- define "powerdns-poweradmin.paName" -}}
{{ include "powerdns-poweradmin.fullname" . }}-poweradmin
{{- end }}

{{- define "powerdns-poweradmin.dbName" -}}
{{ include "powerdns-poweradmin.fullname" . }}-postgresql
{{- end }}

{{- define "powerdns-poweradmin.secretName" -}}
{{- if .Values.secrets.existingSecret -}}
{{ .Values.secrets.existingSecret }}
{{- else -}}
{{ include "powerdns-poweradmin.fullname" . }}-secrets
{{- end -}}
{{- end }}
