FROM ubuntu:18.04

RUN useradd -G video -m -s /bin/bash e2user
RUN apt-get update && apt-get -y install sudo
RUN adduser e2user sudo && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

ENV TZ=Europe
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# build requirements
RUN apt-get install -y \
  git build-essential autoconf autotools-dev libtool libtool-bin checkinstall unzip \
  swig python-dev python-twisted \
  libz-dev libssl-dev \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libsigc++-2.0-dev \
  libfreetype6-dev libsigc++-2.0-dev libfribidi-dev \
  libavahi-client-dev libjpeg-dev libgif-dev libsdl2-dev

RUN apt-get install -y libsdl1.2-dev

# xserver
RUN apt-get install -y x11vnc xvfb
# web server
RUN apt-get install -y apache2

# enigma2 wants python-wifi
RUN apt-get -y install python-pip && pip install python-wifi

# opkg dependencies
RUN apt-get install -y libarchive-dev libcurl4-openssl-dev libgpgme11-dev

WORKDIR /work

ARG OPKG_VER="0.3.5"
RUN curl "https://git.yoctoproject.org/opkg/snapshot/opkg-$OPKG_VER.tar.gz" -o opkg.tar.gz
RUN tar -xzf opkg.tar.gz \
 && cd "opkg-$OPKG_VER" \
 && ./autogen.sh \
 && ./configure --enable-curl --enable-ssl-curl --enable-gpg \
 && make \
 && make install

RUN git clone --depth 10 git://git.opendreambox.org/git/obi/libdvbsi++.git
RUN cd libdvbsi++ \
 && ./autogen.sh \
 && ./configure \
 && make \
 && make install

RUN git clone --depth 10 git://github.com/OpenPLi/tuxtxt.git
RUN cd tuxtxt/libtuxtxt \
 && autoreconf -i \
 && CPP="gcc -E -P" ./configure --with-boxtype=generic --prefix=/usr \
 && make \
 && make install
RUN cd tuxtxt/tuxtxt \
 && autoreconf -i \
 && CPP="gcc -E -P" ./configure --with-boxtype=generic --prefix=/usr \
 && make \
 && make install

RUN apt-get update && apt-get install -y libxml2-dev gcc-8 g++-8

RUN git clone --depth 5 https://github.com/mx3L/enigma2.git -b sdl

ENV CC=gcc-8 
ENV CXX=g++-8
RUN cd enigma2 \
 && ./autogen.sh \
 && ./configure --with-libsdl --with-gstversion=1.0 --prefix=/usr --sysconfdir=/etc \
 && make -j4 \
 && make install
# disable startup wizards
COPY enigma2-settings /etc/enigma2/settings
RUN ldconfig

RUN apt-get install -y xdotool

RUN apt-get install -y bash-completion command-not-found psmisc htop vim wget mc
RUN apt-get install -y gstreamer1.0-plugins-bad gstreamer1.0-plugins-good gstreamer1.0-plugins-ugly gstreamer1.0-libav
RUN apt-get install -y python-pip python-netifaces
RUN pip install --upgrade pip
RUN pip install requests

WORKDIR /work

RUN git clone https://github.com/mx3L/servicemp3.git -b sdl_appsink
RUN cd servicemp3 \
 && ./autogen.sh \
 && ./configure --prefix=/usr \
 && make -j4 && make install

RUN git clone https://github.com/mx3L/gst-plugin-subsink.git
RUN cd gst-plugin-subsink \
 && autoreconf -i \
 && ./configure --with-gstversion=1.0 --prefix=/usr \
 && make -j4 && make install
RUN cp /usr/lib/gstreamer-1.0/libgstsubsink.so /usr/lib/x86_64-linux-gnu/gstreamer-1.0

RUN git clone https://github.com/littlesat/skin-PLiHD.git
WORKDIR /work/skin-PLiHD/usr/share/enigma2

RUN cp -r PLi-FullHD /usr/share/enigma2 \
&& cp -r PLi-HD /usr/share/enigma2 \
&& cp -r PLi-HD1 /usr/share/enigma2 \
&& cp -r PLi-HD2 /usr/share/enigma2 

RUN printf 'config.misc.firstrun=false\n' > /etc/enigma2/settings \
&& printf 'config.misc.initialchannelselection=false\n' >> /etc/enigma2/settings \
&& printf 'config.misc.languageselected=false\n' >> /etc/enigma2/settings \ 
&& printf 'config.misc.videowizardenabled=false\n' >> /etc/enigma2/settings \
&& printf 'config.skin.primary_skin=PLi-HD/skin.xml\n' >> /etc/enigma2/settings \
&& printf 'config.usage.setup_level=expert\n' >> /etc/enigma2/settings

COPY entrypoint.sh /opt
COPY runenigma2.sh /opt

RUN chmod 755 /opt/entrypoint.sh
ENV DISPLAY=:99
EXPOSE 5900 80
ENTRYPOINT ["/opt/entrypoint.sh"]
CMD bash
CMD [ "x11vnc", "-forever" ]

