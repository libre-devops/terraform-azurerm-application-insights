<!--
  Header for the complete example README. Edit this file, then run `just docs`
  (or ./Sort-LdoTerraform.ps1 -IncludeExamples) to regenerate the section between the markers.
  The example's main.tf is embedded into the README automatically (see .terraform-docs.yml).
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="200">
    </picture>
  </a>
</div>

# Complete example

The full surface of the module: an RBAC-posture component with every tuning knob (retention, daily
cap and notifications, sampling, IP masking, internet toggles, profiler storage), the Monitoring
Metrics Publisher grant wired to a workload identity created in the same plan (proving the
plan-known grant keys), API keys (read and write scoped), analytics items (a saved query and a
function with an alias), smart detection rule tuning, and a second component deliberately opted into
legacy instrumentation-key ingestion so the posture check is visible in the plan output. Run it with
`just e2e complete`, which applies the stack then always destroys it.

[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)
