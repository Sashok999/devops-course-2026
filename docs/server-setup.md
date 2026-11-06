## 8. Веб-сервер

На Ubuntu установить пакеты `nginx` и `rsync`. Служба `nginx` слушает 80/tcp и 443/tcp. Доступ с хоста проверить через `sudo ufw status verbose`.

Создать каталог сайта и назначить владельца деплоя:

```bash
sudo install -d -o devops -g devops -m 755 /var/www/devops-site
```

Конфигурация сайта хранится в `/etc/nginx/sites-available/devops-site`:

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name devops.local;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name devops.local;

    ssl_certificate /etc/ssl/certs/devops.crt;
    ssl_certificate_key /etc/ssl/private/devops.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    root /var/www/devops-site;
    index index.html;
    location / {
        try_files $uri $uri/ =404;
    }

    error_page 404 /404.html;
    access_log /var/log/nginx/devops-site.access.log;
    error_log /var/log/nginx/devops-site.error.log;
}
```

При первичной настройке выпустить самоподписанный сертификат на 365 дней с SAN `DNS:devops.local`:

```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/devops.key -out /etc/ssl/certs/devops.crt \
  -subj '/CN=devops.local' -addext 'subjectAltName=DNS:devops.local'
sudo chown root:root /etc/ssl/private/devops.key /etc/ssl/certs/devops.crt
sudo chmod 600 /etc/ssl/private/devops.key
sudo chmod 644 /etc/ssl/certs/devops.crt
sudo ln -s /etc/nginx/sites-available/devops-site /etc/nginx/sites-enabled/devops-site
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

На хосте скопировать открытый сертификат по SSH и проверить сайт. Имя `devops.local` должно указывать на IP гостевой машины в сети Host-only:

```bash
scp devops:/etc/ssl/certs/devops.crt ~/devops.crt
scripts/deploy.sh --dry-run
scripts/deploy.sh
curl -I http://devops.local/
curl --cacert ~/devops.crt -I https://devops.local/
```

Владелец опубликованных файлов — `devops:devops`, режим каталогов — 755, файлов — 644. Скрипт деплоя назначает эти режимы через `rsync --chmod=D755,F644`. Ключ остаётся на сервере, а срок сертификата проверяется через `openssl x509 -in /etc/ssl/certs/devops.crt -noout -dates`.
