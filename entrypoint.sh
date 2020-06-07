#! /bin/bash
if [[ -z "${UUID}" ]]; then
  UUID="4890bd47-5180-4b1c-9a5d-3ef686543112"
fi

if [[ -z "${AlterID}" ]]; then
  AlterID="10"
fi

if [[ -z "${V2_Path}" ]]; then
  V2_Path="/FreeApp"
fi

if [[ -z "${V2_QR_Path}" ]]; then
  V2_QR_Code="1234"
fi

root_dir=/root/workplace/proxy/

rm -rf /etc/localtime
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
date -R

SYS_Bit="$(getconf LONG_BIT)"
[[ "$SYS_Bit" == '32' ]] && BitVer='_linux_386.tar.gz'
[[ "$SYS_Bit" == '64' ]] && BitVer='_linux_amd64.tar.gz'

# download v2ray core 
if [ "$VER" = "latest" ]; then
  V_VER=`curl -s -L "https://api.github.com/repos/v2ray/v2ray-core/releases/latest" | jq -r ".tag_name"`
else
  V_VER="v$VER"
fi

v2raydir=${root_dir}/v2raybin
if [ -d ${v2raydir} ]; then
	mkdir -p ${v2raydir}
fi
cd ${v2raydir}

wget --no-check-certificate -qO 'v2ray.zip' "https://github.com/v2ray/v2ray-core/releases/download/$V_VER/v2ray-linux-$SYS_Bit.zip"
unzip v2ray.zip -d ${v2raydir}/v2ray-$V_VER-linux-$SYS_Bit/
rm -rf v2ray.zip
chmod +x ${v2raydir}/v2ray-$V_VER-linux-$SYS_Bit/*

# download caddy 
C_VER=`wget -qO- "https://api.github.com/repos/mholt/caddy/releases/latest" | jq -r ".tag_name"`

caddydir=${root_dir}/v2raybin
if [ -d ${caddydir} ]; then
	mkdir -p ${caddydir}
fi
cd ${caddydir}

wget --no-check-certificate -qO 'caddy.tar.gz' "https://github.com/mholt/caddy/releases/download/$C_VER/caddy_$C_VER$BitVer"
tar xvf caddy.tar.gz
rm -rf caddy.tar.gz
chmod +x caddy
cd /root

wwwdir=${root_dir}/wwwroot
if [ -d ${wwwdir} ]; then
	mkdir -p ${wwwdir}
fi
cd ${wwwdir}

wget --no-check-certificate -qO 'demo.tar.gz' "https://github.com/ki8852/v2ray-heroku-undone/raw/master/demo.tar.gz"
tar xvf demo.tar.gz
rm -rf demo.tar.gz

cat <<-EOF > ${v2raydir}/v2ray-$V_VER-linux-$SYS_Bit/config.json
{
    "log":{
        "loglevel":"warning"
    },
    "inbound":{
        "protocol":"vmess",
        "listen":"127.0.0.1",
        "port":2333,
        "settings":{
            "clients":[
                {
                    "id":"${UUID}",
                    "level":1,
                    "alterId":${AlterID}
                }
            ]
        },
        "streamSettings":{
            "network":"ws",
            "wsSettings":{
                "path":"${V2_Path}"
            }
        }
    },
    "outbound":{
        "protocol":"freedom",
        "settings":{
        }
    }
}
EOF

cat <<-EOF > ${caddydir}/Caddyfile
http://0.0.0.0:${PORT}
{
	root ${wwwdir}
	index index.html
	timeouts none
	proxy ${V2_Path} localhost:2333 {
		websocket
		header_upstream -Origin
	}
}
EOF

cat <<-EOF > ${v2raydir}/vmess.json 
{
    "v": "2",
    "ps": "${AppName}.herokuapp.com",
    "add": "${AppName}.herokuapp.com",
    "port": "443",
    "id": "${UUID}",
    "aid": "${AlterID}",			
    "net": "ws",			
    "type": "none",			
    "host": "",			
    "path": "${V2_Path}",	
    "tls": "tls"			
}
EOF

if [ "$AppName" = "no" ]; then
  echo "不生成二维码"
else
  mkdir ${wwwdir}/$V2_QR_Path
  vmess="vmess://$(cat ${v2raydir}/vmess.json | base64 -w 0)" 
  Linkbase64=$(echo -n "${vmess}" | tr -d '\n' | base64 -w 0) 
  echo "${Linkbase64}" | tr -d '\n' > ${wwwdir}/$V2_QR_Path/index.html
  echo -n "${vmess}" | qrencode -s 6 -o ${wwwdir}/$V2_QR_Path/v2.png
fi

cd ${v2raydir}/v2ray-$V_VER-linux-$SYS_Bit && ./v2ray &
cd ${caddydir} && ./caddy -conf="Caddyfile"
