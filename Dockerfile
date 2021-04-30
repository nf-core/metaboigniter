FROM container-registry.phenomenal-h2020.eu/phnmnl/rbase:dev_v3.4.4-1xenial0_cv1.0.20

LABEL authors="Payam Emami" \
      description="Docker image containing all software requirements for the nf-core/metaboigniter pipeline"

RUN sed -i 's/# \(.*multiverse$\)/\1/g' /etc/apt/sources.list && \
      	apt-get update && \
      	apt-get -y upgrade && \
      	apt-get install -y byobu curl git htop man unzip vim wget && \
      	apt-get install -y cmake flex bison python-numpy python-dev sqlite3 \
        libsqlite3-dev libboost-dev libboost-system-dev libboost-thread-dev libboost-serialization-dev libboost-python-dev libboost-regex-dev && \
 apt-get -y update &&  apt-get install -y software-properties-common && add-apt-repository ppa:beineri/opt-qt59-xenial && \
apt-get -y update && 	apt-get install -y --no-install-recommends \
make gcc gfortran g++ libnetcdf-dev libxml2-dev libblas-dev liblapack-dev libssl-dev pkg-config git \
autoconf patch libtool make automake wget build-essential cmake python python-pip libqtgui4 python-setuptools && \
	apt-get install -y ninja-build qt5-default libqt5serialport5-dev qtscript5-dev libqt5svg5-dev zip  && \
apt-get -y update && apt-get install -y qt59base qt59imageformats qt59quickcontrols qt59quickcontrols2 qt59webengine && \
 apt-get -y update && \
    apt-get install -y subversion libboost-filesystem-dev software-properties-common && \
    add-apt-repository ppa:openjdk-r/ppa && apt-get -y update && apt-get -y install wget openjdk-11-jdk parallel && \

 R -e 'source("https://bioconductor.org/biocLite.R"); biocLite(c("MSnbase","mzR","MassSpecWavelet","S4Vectors","BiocStyle","faahKO","msdata"))' && \
 R -e 'source("https://bioconductor.org/biocLite.R");biocLite(c("lattice","RColorBrewer","plyr","RANN","multtest","knitr","ncdf4","microbenchmark","RUnit"))'&& \
 R -e 'source("https://bioconductor.org/biocLite.R");biocLite("devtools")'&& \
 R -e 'source("https://bioconductor.org/biocLite.R");biocLite("ncdf4")'&& \
 R -e 'devtools::install_version("latticeExtra")'&& \
 R -e 'library(devtools); source("https://bioconductor.org/biocLite.R"); biocLite("xcms")' && \
 R -e 'source("https://bioconductor.org/biocLite.R");biocLite(c("survival"),"latticeExtra")' && \
 R -e 'devtools::install_version("survival",version="3.1.6")' && \
 R -e 'library(devtools); source("https://bioconductor.org/biocLite.R"); biocLite("CAMERA")' && \
 R -e 'source("https://bioconductor.org/biocLite.R");biocLite(c("irlba","igraph","XML","intervals"))'  && \
 R -e 'source("https://bioconductor.org/biocLite.R");biocLite(c("zip"))'  && \
 R -e 'source("https://bioconductor.org/biocLite.R");biocLite(c("zip"))'  && \
 R -e 'source("https://bioconductor.org/biocLite.R");biocLite(c("IPO"))' && \
 R -e 'install.packages(c("R.utils","tools","argparse"),repos = "http://cran.us.r-project.org")' && \
echo "deb http://cloud.r-project.org/bin/linux/ubuntu trusty/" >> /etc/apt/sources.list && \
     apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E084DAB9 && \
     R -e 'source("https://bioconductor.org/biocLite.R");biocLite("tools")' && \
 apt-get -y clean && apt-get -y autoremove && rm -rf /var/lib/{cache,log}/ /tmp/* /var/tmp/*


## install OpenMS
RUN mkdir /openMS
ADD https://abibuilder.informatik.uni-tuebingen.de/archive/openms/OpenMSInstaller/release/2.4.0/OpenMS-2.4.0-Debian-Linux-x86_64.deb /openMS

RUN /bin/bash -c "source /opt/qt59/bin/qt59-env.sh"
ENV OPENMS_DATA_PATH=/usr/share/OpenMS
ENV QT_BASE_DIR=/opt/qt59
ENV QTDIR=$QT_BASE_DIR
ENV PATH=$QT_BASE_DIR/bin:$PATH
ENV LD_LIBRARY_PATH=$QT_BASE_DIR/lib/x86_64-linux-gnu:$QT_BASE_DIR/lib:$LD_LIBRARY_PATH
ENV PKG_CONFIG_PATH=$QT_BASE_DIR/lib/pkgconfig:$PKG_CONFIG_PATH
RUN dpkg -i /openMS/OpenMS-2.4.0-Debian-Linux-x86_64.deb

### CFM ID

ENV RDKIT_VERSION Release_2016_03_3

# Set home directory
#ENV HOME /root
RUN mkdir /engine
WORKDIR /engine

# Download dependencies


# Compile rdkit
ADD https://github.com/rdkit/rdkit/archive/$RDKIT_VERSION.tar.gz /engine/
RUN tar xzvf $RDKIT_VERSION.tar.gz && \
	rm $RDKIT_VERSION.tar.gz

RUN cd /engine/rdkit-$RDKIT_VERSION/External/INCHI-API && \
	./download-inchi.sh

RUN mkdir /engine/rdkit-$RDKIT_VERSION/build && \
	cd /engine/rdkit-$RDKIT_VERSION/build && \
	cmake -DRDK_BUILD_INCHI_SUPPORT=ON .. && \
	make && \
	make install

# Set environmental variables
ENV RDBASE /engine/rdkit-$RDKIT_VERSION
ENV LD_LIBRARY_PATH $RDBASE/lib
ENV PYTHONPATH $PYTHONPATH:$RDBASE


#ENV HOME /root
WORKDIR /engine

# Add sources
RUN mkdir /engine/lp_solve_5.5.2
#https://sourceforge.net/projects/lpsolve/files/lpsolve/5.5.2.11/lp_solve_5.5.2.11_source.tar.gz
ADD https://downloads.sourceforge.net/project/lpsolve/lpsolve/5.5.2.11/lp_solve_5.5.2.11_source.tar.gz /engine/
RUN tar xzvf lp_solve_5.5.2.11_source.tar.gz -C /engine/lp_solve_5.5.2 && \
	rm lp_solve_5.5.2.11_source.tar.gz

# Compile LPSolve
RUN ls /engine/lp_solve_5.5.2
RUN chmod +x /engine/lp_solve_5.5.2/lp_solve_5.5/lpsolve55/ccc
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-cfmid/develop/fix-lpsolve-compilation.patch /engine/lp_solve_5.5/lpsolve55
#RUN cd /engine/lp_solve_5.5/lpsolve55 && patch ccc < fix-lpsolve-compilation.patch && ./ccc
RUN cd /engine/lp_solve_5.5.2/lp_solve_5.5/lpsolve55 &&  ./ccc

RUN mkdir cfm-id-code
RUN cd cfm-id-code && git clone https://github.com/PayamEmami/CFM-ID.git && mv CFM-ID cfm

RUN ls -l /engine/lp_solve_5.5.2/lp_solve_5.5/lpsolve55/bin/ux64 && \
	mkdir /engine/cfm-id-code/cfm/build && \
	cd /engine/cfm-id-code/cfm/build && \
	cmake .. -DLPSOLVE_INCLUDE_DIR=/engine/lp_solve_5.5.2/lp_solve_5.5 -DLPSOLVE_LIBRARY_DIR=/engine/lp_solve_5.5.2/lp_solve_5.5/lpsolve55/bin/ux64 && \
	make install

# Set environmental variables
ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:$RDBASE/lib:/engine/lp_solve_5.5.2/lp_solve_5.5/lpsolve55/bin/ux64
ENV PATH $PATH:/engine/cfm-id-code/cfm/bin

RUN cd /engine/cfm-id-code/cfm/supplementary_material/trained_models/esi_msms_models/negative_metab_se_cfm/ && unzip negative_se_params.zip && \
 cd /engine/cfm-id-code/cfm/supplementary_material/trained_models/esi_msms_models/metab_se_cfm/ && unzip params_metab_se_cfm.zip

ENV software_version="3.4.4-1trusty0"

RUN pip install -Iv pyopenms==2.1.0

## Metfrag
ADD bin/jni-inchi-0.8.jar /root
RUN mkdir -p /root/.jnati/repo/ && jar xf /root/jni-inchi-0.8.jar && mv META-INF/jniinchi /root/.jnati/repo/

ADD bin/metfrag.jar /usr/share/metfrag-2.4.5-1/metfrag.jar

# Install csi

# Install development files needed
RUN git clone https://github.com/MetaboIGNITER/container-csifingerid.git && cd container-csifingerid && \
git checkout sirius-4.5.1 && mkdir -p /usr/bin/CSI && cp -a sirius-4.5.1/. /usr/bin/CSI && \
rm -rf sirius-4.5.1

RUN chmod +x /usr/bin/CSI/bin/sirius


## container passatutto
RUN git clone https://github.com/MetaboIGNITER/container-passatutto.git && cd container-passatutto && \
 mkdir -p /usr/bin/Passatutto && cp -a passatutto/Passatutto/. /usr/bin/Passatutto && \
 rm -rf passatutto

#
ADD bin/run_metfrag.sh /usr/bin/run_metfrag.sh




ADD bin/*.r /usr/bin/

ADD bin/featurexmltotable.py /usr/bin/featurexmltotable.py
ADD bin/metfrag /usr/share/metfrag-2.4.5-1/metfrag

RUN chmod +x /usr/bin/*.r && chmod +x /usr/bin/CSI/bin/sirius &&\
 chmod +x /usr/bin/featurexmltotable.py  &&\
 chmod +x /usr/share/metfrag-2.4.5-1/metfrag  &&\
 chmod +x /usr/bin/run_metfrag.sh  &&\
 ln -s /usr/share/metfrag-2.4.5-1/metfrag /usr/bin/



RUN /bin/bash -c "source /opt/qt59/bin/qt59-env.sh"
ENV OPENMS_DATA_PATH=/usr/share/OpenMS
ENV QT_BASE_DIR=/opt/qt59
ENV QTDIR=$QT_BASE_DIR
ENV PATH=$QT_BASE_DIR/bin:$PATH
ENV LD_LIBRARY_PATH=$QT_BASE_DIR/lib/x86_64-linux-gnu:$QT_BASE_DIR/lib:$LD_LIBRARY_PATH
ENV PKG_CONFIG_PATH=$QT_BASE_DIR/lib/pkgconfig:$PKG_CONFIG_PATH


RUN /usr/bin/printf '\xfe\xed\xfe\xed\x00\x00\x00\x02\x00\x00\x00\x00\xe2\x68\x6e\x45\xfb\x43\xdf\xa4\xd9\x92\xdd\x41\xce\xb6\xb2\x1c\x63\x30\xd7\x92' > /etc/ssl/certs/java/cacerts
RUN /var/lib/dpkg/info/ca-certificates-java.postinst configure
