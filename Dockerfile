FROM debian:jessie-slim

ENV LANG C.UTF-8

#COPY java /usr/local/java
COPY jre /usr/local/java
COPY tomcat /usr/local/tomcat
# COPY tingyun /usr/local/
COPY tomcat-native.tar.gz /usr/local/

ENV JAVA_HOME /usr/local/java
#ENV CLASSPATH .:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar
ENV JAVA_VERSION 6u45
ENV CATALINA_HOME /usr/local/tomcat
ENV PATH $CATALINA_HOME/bin:$JAVA_HOME/bin:$PATH
WORKDIR $CATALINA_HOME


# let "Tomcat Native" live somewhere isolated
ENV TOMCAT_NATIVE_LIBDIR $CATALINA_HOME/native-jni-lib
ENV LD_LIBRARY_PATH ${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$TOMCAT_NATIVE_LIBDIR

# runtime dependencies for Tomcat Native Libraries
# Tomcat Native 1.2+ requires a newer version of OpenSSL than debian:jessie has available
# > checking OpenSSL library version >= 1.0.2...
# > configure: error: Your version of OpenSSL is not compatible with this version of tcnative
# see http://tomcat.10.x6.nabble.com/VOTE-Release-Apache-Tomcat-8-0-32-tp5046007p5046024.html (and following discussion)
# and https://github.com/docker-library/tomcat/pull/31
ENV OPENSSL_VERSION 1.1.0f-3+deb9u2
# timezone setting
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone; \
    set -ex; \
		if ! grep -q stretch /etc/apt/sources.list; then \
# only add stretch if we're not already building from within stretch
			{ \
				echo 'deb http://deb.debian.org/debian stretch main'; \
				echo 'deb http://security.debian.org stretch/updates main'; \
				echo 'deb http://deb.debian.org/debian stretch-updates main'; \
			} > /etc/apt/sources.list.d/stretch.list; \
			{ \
# add a negative "Pin-Priority" so that we never ever get packages from stretch unless we explicitly request them
				echo 'Package: *'; \
				echo 'Pin: release n=stretch*'; \
				echo 'Pin-Priority: -10'; \
				echo; \
# ... except OpenSSL, which is the reason we're here
				echo 'Package: openssl libssl*'; \
				echo "Pin: version $OPENSSL_VERSION"; \
				echo 'Pin-Priority: 990'; \
			} > /etc/apt/preferences.d/stretch-openssl; \
		fi; \
        mv -v /etc/apt/sources.list /etc/apt/sources.list.bak && \
        echo "deb http://mirrors.163.com/debian/ jessie main non-free contrib" >/etc/apt/sources.list && \
        echo "deb http://mirrors.163.com/debian/ jessie-proposed-updates main non-free contrib" >>/etc/apt/sources.list && \
        echo "deb-src http://mirrors.163.com/debian/ jessie main non-free contrib" >>/etc/apt/sources.list && \
        echo "deb-src http://mirrors.163.com/debian/ jessie-proposed-updates main non-free contrib" >>/etc/apt/sources.list; \
		apt-get update; \
		apt-get install -y --no-install-recommends openssl="$OPENSSL_VERSION"; \
		rm -rf /var/lib/apt/lists/*; \
    apt-get update && apt-get install -y --no-install-recommends \
		bzip2 \
		unzip \
		xz-utils \
        libapr1 \
        openssl \
        dpkg-dev \
        gcc \
        libapr1-dev \
        libssl-dev \
        make \
	&& rm -rf /var/lib/apt/lists/*; \
    set -eux; \
    nativeBuildDir="$(mktemp -d)"; \
	tar -xvf /usr/local/tomcat-native.tar.gz -C "$nativeBuildDir" --strip-components=1; \
	( \
		export CATALINA_HOME="$PWD"; \
		cd "$nativeBuildDir/native"; \
		gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
		./configure \
			--build="$gnuArch" \
			--libdir="$TOMCAT_NATIVE_LIBDIR" \
			--prefix="$CATALINA_HOME" \
			--with-apr="$(which apr-1-config)" \
			--with-java-home="$JAVA_HOME" \
			--with-ssl=yes; \
		make -j "$(nproc)"; \
		make install; \
	); \
	rm -rf "$nativeBuildDir"; \
	rm /usr/local/tomcat-native.tar.gz;

EXPOSE 8080

CMD ["catalina.sh", "run"]
