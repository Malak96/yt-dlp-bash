#!/bin/bash
# Verificar si existe el archivo config.ini
if [[ -f "config.ini" ]]; then
    echo "Leyendo configuraciones desde config.ini..."
    while IFS='=' read -r key value; do
        case "$key" in
            "downloadpath") downloadpath="$value" ;;
            "kbps") kbps="$value" ;;
            "format") format="$value" ;;
        esac
    done < config.ini
else
    echo "No se encontro config.ini, creando con configuraciones por defecto..."
    echo -e "[config]\ndownloadpath=/mnt/usb0/media/Musica\nkbps=0\nformat=m4a" > config.ini
    downloadpath="\downloadpath=/mnt/usb0/media/Musica"
    kbps="0"
    format="mp3"
fi

# Configuraciones
YT_DLP="./yt-dlp"
msg_complete="Listo!"
msg_error="Ocurrio un error:"

# Verificar dependencias
if ! command -v "$YT_DLP" &> /dev/null; then
    echo "El archivo yt-dlp no se encuentra en el directorio. Intentando descargarlo..."
    curl -L -o yt-dlp https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp
    chmod +x yt-dlp
fi
echo
# Inicio
while :; do
    echo "Ingresa una URL o presiona Enter para ver las descargas:"
    echo
    read -p "::" URL
    echo
    [[ "$URL" == "x" ]] && exit

    if [[ "$URL" =~ ^http://|^https:// ]]; then
        echo "Trabajando, espera..."
    else
        echo "Buscando \"$URL\""
        URL="ytsearch:$URL"
    fi

    if [[ -z "$URL" ]]; then
        mkdir -p "$downloadpath"
        xdg-open "$downloadpath" &> /dev/null
        continue
    fi

echo
# Spinner function
spinner() {
    local pid=$1
    local delay=0.1
    local spin='|/-\'
    tput civis  # Ocultar cursor

    while kill -0 "$pid" 2>/dev/null; do
        for i in $(seq 0 3); do
            printf "\r[%c] Descargando y procesando..." "${spin:$i:1}"
            sleep $delay
        done
    done
    printf "\r\033[K"  # Limpia la línea final del spinner
    tput cnorm  # Restaurar cursor
}

# Variables necesarias

LOG_FILE=$(mktemp)  # Archivo temporal para capturar la salida

# Ejecuta yt-dlp en segundo plano y redirige la salida a un archivo temporal
("$YT_DLP" --format "bestaudio[ext=m4a]/bestaudio[ext=opus]/bestaudio" \
    --output "$downloadpath/%(title)s.%(ext)s" \
    --ppa "ffmpeg:-id3v2_version 3" \
    --cookies ./cookies.txt \
    --audio-format "$format" \
    --embed-thumbnail \
    --extract-audio \
    --add-metadata \
    --no-overwrites \
    --progress \
    --no-playlist \
    --print "before_dl:>>" \
    --print "before_dl:Titulo: %(title)s" \
    --print "before_dl:Artista: %(artist)s" \
    --print "before_dl:Album: %(album)s" \
    --print "before_dl:Lanzamiento: %(release_year)s" \
    --print "before_dl:>>" \
    --no-warnings -q "$URL" > "$LOG_FILE" 2>&1) &

pid=$!  # Captura el PID del comando en segundo plano

# Ejecuta el spinner mientras el comando está corriendo
spinner $pid

wait $pid  # Espera a que el proceso termine
echo "[✔] Descarga y procesamiento completados"

cat "$LOG_FILE" | awk '{print $0}'  # Formatea la salida con prefijo
rm -f "$LOG_FILE"  # Limpia el archivo temporal

    if [[ $? -ne 0 ]]; then
        echo "$msg_error"
    fi
done 
