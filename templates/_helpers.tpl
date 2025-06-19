{{/*
Expand the name of the chart.
*/}}
{{- define "gop.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 50 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 50 chars because some Kubernetes name fields are limited to 50 (by the DNS naming spec).
Then we add the valuesHash (8 chars) and each pod of job ges another 5 chars added.
If release name contains chart name it will be used as a full name.
*/}}

{{- define "gop.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 50 | trimSuffix "-" }}-{{ include "valuesHash" . | lower }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 50 | trimSuffix "-" }}-{{ include "valuesHash" . | lower }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 50 | trimSuffix "-" }}-{{ include "valuesHash" . | lower }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "gop.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 50 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "gop.labels" -}}
helm.sh/chart: {{ include "gop.chart" . }}
{{ include "gop.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "gop.selectorLabels" -}}
app.kubernetes.io/name: {{ include "gop.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "gop.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "gop.fullname" .) .Values.serviceAccount.name }}-{{ include "valuesHash" . | lower }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}-{{ include "valuesHash" . | lower }}
{{- end }}
{{- end }}

{{/*
Generate a SHA256 hash of all merged .Values
Usage: {{ include "valuesHash" . }}
*/}}
{{- define "valuesHash" -}}
{{- toJson .Values | sha256sum | trunc 8 -}}
{{- end }}