#!/usr/bin/env bash
_kubie_completions() {
    local cur prev words cword
    _init_completion || return

    local cmd="${words[1]}"

    case "$cmd" in
        ctx)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "-u --unset -f --fish -z --zsh" -- "$cur"))
                return 0
            fi
            local contexts=""
            if command -v kubectl >/dev/null 2>&1; then
                contexts=$(kubectl config get-contexts --no-headers -o name 2>/dev/null)
            elif [[ -f "${KUBECONFIG:-$HOME/.kube/config}" ]]; then
                contexts=$(grep -E '^\s*-\s*name:' "${KUBECONFIG:-$HOME/.kube/config}" | awk '{print $NF}')
            fi
            COMPREPLY=($(compgen -W "$contexts" -- "$cur"))
            return 0
            ;;
        ns)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "-f --fish -z --zsh" -- "$cur"))
                return 0
            fi
            local target_ctx=""
            for ((i = 2; i < cword; i++)); do
                if [[ "${words[i]}" == "-c" || "${words[i]}" == "--context" ]]; then
                    target_ctx="${words[i+1]}"
                    break
                fi
            done
            local ns_list=""
            if command -v kubectl >/dev/null 2>&1; then
                local ctx_arg=()
                [[ -n "$target_ctx" ]] && ctx_arg=(--context "$target_ctx")
                ns_list=$(kubectl get namespaces "${ctx_arg[@]}" --no-headers -o custom-columns=":metadata.name" 2>/dev/null)
            fi
            COMPREPLY=($(compgen -W "$ns_list" -- "$cur"))
            return 0
            ;;
        *)
            if [[ $cword -eq 1 ]]; then
                COMPREPLY=($(compgen -W "ctx ns exec edit lint info update help" -- "$cur"))
                return 0
            fi
            ;;
    esac
}
complete -F _kubie_completions kubie
