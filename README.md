Tomcat6的docker 镜像

tomcat6.docker 文件是打包的本地文件，可以直接用docker load -i tomcat6.docker

# 构建镜像
`docker build -t zhaopei/tomcat6 .`

拉取镜像
`docker pull zhaopei8948/tomcat`

运行
`docker run -it --rm zhaopei8948/tomcat:6`
