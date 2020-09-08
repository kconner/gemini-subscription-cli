#!/bin/sh

cached_links_path="./cached-links.gmi"
temp_response_path=$(mktemp /tmp/gemini-diff-response.XXXXXX)
temp_links_path=$(mktemp /tmp/gemini-diff-links.XXXXXX)

# Loop over subscription URLs given as lines to stdin
for url in $(cat /dev/stdin)
do
    while true
    do
        # Parse the URL
        url_scheme=$(echo -n "$url" | sed -E 's_^([^:]*):.*$_\1_')
        url_domain=$(echo -n "$url" | sed -E 's_^[^:]*:(//)?([^:/]*).*$_\2_')
        url_port=$(echo -n "$url" | sed -E 's_^[^:]*:(//)?[^:/]*(:([^/]*))?.*$_\3_')
        url_port=${url_port:-1965}
        url_path=$(echo -n "$url" | sed -E 's_^[^:]*:(//)?[^/]*(/.*)?$_\2_')
        url_path=${url_path:-/}

        # Run the Gemini request
        # include a sleep because socat will stop reading data when input hits EOF
        (printf "${url_scheme}://${url_domain}:${url_port:-1965}${url_path}\r\n" ; sleep 2) | socat "openssl:${url_domain}:${url_port},verify=0" stdio > "$temp_response_path"

        response_status_code=$(cat "$temp_response_path" | head -1 | sed -E 's/^([0-9]*).*$/\1/')
        case "$response_status_code" in
            31)
                # Redirect
                >&2 echo "redirected: $url"
                url=$(cat "$temp_response_path" | head -1 | sed -E 's/^([0-9]*) *(.*)$/\2/')
                ;;
            20)
                # Success
                >&2 echo "fetched: $url"
                break
                ;;
            *)
                >&2 echo "unsupported status code: $url"
                >&2 cat "$temp_response_path"
                exit
                ;;
        esac
    done

    # Find all the links on the page
    response_links=$(cat "$temp_response_path" | tail +2 | egrep '^=>')
    echo "$response_links" >> "$temp_links_path"
done

# Print out only links not known to cache
diff --new-file "$cached_links_path" "$temp_links_path" | egrep '^>' | cut -c 3-

# Save links to compare for next time
mv "$temp_links_path" "$cached_links_path"

# Clean up
rm "$temp_response_path"
