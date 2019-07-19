while true; do
    printf "%c" "."
    sleep 5
done

if [ "$1" = "kill"]; then
  kill -9 $$
fi
