FROM container-registry.phenomenal-h2020.eu/phnmnl/rbase:dev_v3.4.4-1xenial0_cv1.0.20
LABEL authors="Payam Emami" \
      description="Docker image containing all software requirements for the nf-core/metaboigniter pipeline"

RUN apt-get -y update && apt-get -y --no-install-recommends install make gcc gfortran g++ libnetcdf-dev libxml2-dev libblas-dev liblapack-dev libssl-dev pkg-config git
RUN R -e 'source("https://bioconductor.org/biocLite.R"); biocLite(c("MSnbase","mzR","MassSpecWavelet","S4Vectors","BiocStyle","faahKO","msdata"))'
RUN R -e 'source("https://bioconductor.org/biocLite.R");biocLite(c("lattice","RColorBrewer","plyr","RANN","multtest","knitr","ncdf4","microbenchmark","RUnit"))'
RUN R -e 'source("https://bioconductor.org/biocLite.R");biocLite("devtools")'
RUN R -e 'source("https://bioconductor.org/biocLite.R");biocLite("ncdf4")'
RUN R -e 'devtools::install_version("latticeExtra")'
RUN R -e 'library(devtools); source("https://bioconductor.org/biocLite.R"); biocLite("xcms")'


RUN R -e 'source("https://bioconductor.org/biocLite.R");biocLite(c("survival"),"latticeExtra")'
RUN R -e 'devtools::install_version("survival",version="3.1.6")'
RUN R -e 'library(devtools); source("https://bioconductor.org/biocLite.R"); biocLite("CAMERA")'

RUN R -e 'source("https://bioconductor.org/biocLite.R");biocLite(c("irlba","igraph","XML","intervals"))'
RUN R -e 'source("https://bioconductor.org/biocLite.R");biocLite(c("zip"))'
RUN R -e 'source("https://bioconductor.org/biocLite.R");biocLite(c("zip"))'
RUN apt-get -y update && apt-get -y --no-install-recommends install make gcc gfortran g++ libnetcdf-dev libxml2-dev libblas-dev liblapack-dev libssl-dev r-base-dev pkg-config git

RUN R -e 'source("https://bioconductor.org/biocLite.R");biocLite(c("IPO"))'


## install OpenMS
RUN mkdir /openMS
ADD https://abibuilder.informatik.uni-tuebingen.de/archive/openms/OpenMSInstaller/release/2.4.0/OpenMS-2.4.0-Debian-Linux-x86_64.deb /openMS

RUN apt-get install -y software-properties-common
RUN add-apt-repository ppa:beineri/opt-qt59-xenial && apt-get -y update && 	apt-get install -y g++ autoconf make patch libtool make git automake wget build-essential cmake && 	apt-get install -y ninja-build qt5-default libqt5serialport5-dev qtscript5-dev libqt5svg5-dev zip
RUN apt-get -y update && apt-get install -y qt59base qt59imageformats qt59quickcontrols qt59quickcontrols2 qt59webengine
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
RUN sed -i 's/# \(.*multiverse$\)/\1/g' /etc/apt/sources.list && \
	apt-get update && \
	apt-get -y upgrade && \
	apt-get install -y build-essential software-properties-common && \
	apt-get install -y byobu curl git htop man unzip vim wget && \
	apt-get install -y cmake flex bison python-numpy python-dev sqlite3 libsqlite3-dev libboost-dev libboost-system-dev libboost-thread-dev libboost-serialization-dev libboost-python-dev libboost-regex-dev

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

# Download dependencies
RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get install -y subversion libboost-filesystem-dev git

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
RUN apt-get update
RUN cd cfm-id-code && git clone https://github.com/PayamEmami/CFM-ID.git && mv CFM-ID cfm

RUN ls -l /engine/lp_solve_5.5.2/lp_solve_5.5/lpsolve55/bin/ux64 && \
	mkdir /engine/cfm-id-code/cfm/build && \
	cd /engine/cfm-id-code/cfm/build && \
	cmake .. -DLPSOLVE_INCLUDE_DIR=/engine/lp_solve_5.5.2/lp_solve_5.5 -DLPSOLVE_LIBRARY_DIR=/engine/lp_solve_5.5.2/lp_solve_5.5/lpsolve55/bin/ux64 && \
	make install

# Set environmental variables
ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:$RDBASE/lib:/engine/lp_solve_5.5.2/lp_solve_5.5/lpsolve55/bin/ux64
ENV PATH $PATH:/engine/cfm-id-code/cfm/bin

RUN cd /engine/cfm-id-code/cfm/supplementary_material/trained_models/esi_msms_models/negative_metab_se_cfm/ && unzip negative_se_params.zip
RUN cd /engine/cfm-id-code/cfm/supplementary_material/trained_models/esi_msms_models/metab_se_cfm/ && unzip params_metab_se_cfm.zip

ENV software_version="3.4.4-1trusty0"

RUN apt-get -y update && apt-get -y --no-install-recommends install python python-pip libqtgui4 python-setuptools && pip install -Iv pyopenms==2.1.0

# Add cran R backport
RUN echo "deb http://cloud.r-project.org/bin/linux/ubuntu trusty/" >> /etc/apt/sources.list && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E084DAB9


RUN  R -e 'source("https://bioconductor.org/biocLite.R");biocLite("tools")'


RUN apt-get -y update && apt-get -y install software-properties-common && add-apt-repository ppa:openjdk-r/ppa && apt-get -y update && apt-get -y install wget openjdk-11-jdk parallel


## Metfrag
RUN wget https://github.com/MetaboIGNITER/container-metfrag-cli-batch/raw/develop/jni-inchi-0.8.jar && mkdir -p /root/.jnati/repo/ && jar xf jni-inchi-0.8.jar && mv META-INF/jniinchi /root/.jnati/repo/

ADD https://github.com/MetaboIGNITER/container-metfrag-cli-batch/raw/develop/metfrag.jar /usr/local/share/metfrag-2.4.5-1/metfrag.jar

# Install csi
RUN R -e 'install.packages(c("R.utils","tools","argparse"),repos = "http://cran.us.r-project.org")'



# Install development files needed

RUN git clone https://github.com/MetaboIGNITER/container-csifingerid.git && cd container-csifingerid && \
git checkout sirius-4.5.1 && mkdir -p /usr/local/bin/CSI && cp -a sirius-4.5.1/. /usr/local/bin/CSI

RUN chmod +x /usr/local/bin/CSI/bin/sirius


## container passatutto
RUN git clone https://github.com/MetaboIGNITER/container-passatutto.git && cd container-passatutto && \
 mkdir -p /usr/local/bin/Passatutto && cp -a passatutto/Passatutto/. /usr/local/bin/Passatutto
##

## Add all the script files:
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-cfmid/develop/scripts/cfmid.r /usr/local/bin/cfmid.r
#
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-metfrag-cli-batch/develop/run_metfrag.sh /usr/local/bin/run_metfrag.sh
RUN chmod +x /usr/local/bin/run_metfrag.sh

#
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-xcms/xcms_ipo/scripts/blankfilter.r /usr/local/bin/blankfilter.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-xcms/xcms_ipo/scripts/cvfilter.r  /usr/local/bin/cvfilter.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-xcms/xcms_ipo/scripts/dilutionfilter.r /usr/local/bin/dilutionfilter.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-xcms/xcms_ipo/scripts/filenameextractor.r /usr/local/bin/filenameextractor.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-xcms/xcms_ipo/scripts/fillPeaks.r /usr/local/bin/fillPeaks.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-xcms/xcms_ipo/scripts/findPeaks.r /usr/local/bin/findPeaks.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-xcms/xcms_ipo/scripts/group.r /usr/local/bin/group.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-xcms/xcms_ipo/scripts/ipo.r /usr/local/bin/ipo.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-xcms/xcms_ipo/scripts/retCor.r /usr/local/bin/retCor.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-xcms/xcms_ipo/scripts/save_chromatogram.r /usr/local/bin/save_chromatogram.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-xcms/xcms_ipo/scripts/setphenotype.r /usr/local/bin/setphenotype.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-xcms/xcms_ipo/scripts/show_chromatogram.r /usr/local/bin/show_chromatogram.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-xcms/xcms_ipo/scripts/test_output.r /usr/local/bin/test_output.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-xcms/xcms_ipo/scripts/xcmsCollect.r /usr/local/bin/xcmsCollect.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-xcms/xcms_ipo/scripts/xcmssplitter.r /usr/local/bin/xcmssplitter.r


#

ADD https://raw.githubusercontent.com/MetaboIGNITER/container-camera/xcms3.0.2/scripts/cameraToFeatureXML.r /usr/local/bin/cameraToFeatureXML.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-camera/xcms3.0.2/scripts/featureXMLToCAMERA.r /usr/local/bin/featureXMLToCAMERA.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-camera/xcms3.0.2/scripts/consensusXMLToXcms.r /usr/local/bin/consensusXMLToXcms.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-camera/xcms3.0.2/scripts/correctBatchEffect.r /usr/local/bin/correctBatchEffect.r

ADD https://raw.githubusercontent.com/MetaboIGNITER/container-camera/xcms3.0.2/scripts/featureXMLToXcms.r /usr/local/bin/featureXMLToXcms.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-camera/xcms3.0.2/scripts/findAdducts.r /usr/local/bin/findAdducts.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-camera/xcms3.0.2/scripts/findIsotopes.r /usr/local/bin/findIsotopes.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-camera/xcms3.0.2/scripts/groupCorr.r /usr/local/bin/groupCorr.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-camera/xcms3.0.2/scripts/groupFWHM.r /usr/local/bin/groupFWHM.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-camera/xcms3.0.2/scripts/mergeVaribales.r /usr/local/bin/mergeVaribales.r

ADD https://raw.githubusercontent.com/MetaboIGNITER/container-camera/xcms3.0.2/scripts/prepareOutput.r /usr/local/bin/prepareOutput.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-camera/xcms3.0.2/scripts/xsAnnotate.r /usr/local/bin/xsAnnotate.r
#
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-msnbase/develop/scripts/MS2ToMetFrag.r /usr/local/bin/MS2ToMetFrag.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-msnbase/develop/scripts/MS2ToMetFragZip.r /usr/local/bin/MS2ToMetFragZip.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-csifingerid/sirius-4.5.1/scripts/fingerID.r /usr/local/bin/fingerID.r

#



ADD https://raw.githubusercontent.com/MetaboIGNITER/container-msnbase/develop/scripts/adductCalculator.r /usr/local/bin/adductCalculator.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-msnbase/develop/scripts/aggregateMetfrag.r /usr/local/bin/aggregateMetfrag.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-msnbase/develop/scripts/collectLibrary.r /usr/local/bin/collectLibrary.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-msnbase/develop/scripts/createLibrary.r /usr/local/bin/createLibrary.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-msnbase/develop/scripts/createLibraryFun.r /usr/local/bin/createLibraryFun.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-msnbase/develop/scripts/functionsMergeFilterMS2.r /usr/local/bin/functionsMergeFilterMS2.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-msnbase/develop/scripts/librarySearchEngine.r /usr/local/bin/librarySearchEngine.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-msnbase/develop/scripts/mapMS2ToCamera.r /usr/local/bin/mapMS2ToCamera.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-msnbase/develop/scripts/mergeFilterMS2.r /usr/local/bin/mergeFilterMS2.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-msnbase/develop/scripts/readMS2MSnBase.r /usr/local/bin/readMS2MSnBase.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-msnbase/develop/scripts/toMetfragCommand.r /usr/local/bin/toMetfragCommand.r
#
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-passatutto/develop/scripts/metfragPEP.r /usr/local/bin/metfragPEP.r
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-openmstoxcms/master/scripts/featurexmltotable.py /usr/local/bin/featurexmltotable.py
ADD https://raw.githubusercontent.com/MetaboIGNITER/container-openmstoxcms/master/scripts/featurexmlToCamera.r /usr/local/bin/featurexmlToCamera.r
#
ADD https://github.com/MetaboIGNITER/container-metfrag-cli-batch/raw/develop/metfrag /usr/local/share/metfrag-2.4.5-1/metfrag

RUN chmod u=x,g=rx,o=rwx -R /usr/local/bin/*.r
RUN chmod u=x,g=rx,o=rwx -R /usr/local/bin/CSI/bin
RUN chmod u=x,g=rx,o=rwx -R /usr/local/bin/featurexmltotable.py
RUN chmod u=x,g=rxw,o=rwx /usr/local/share/metfrag-2.4.5-1/metfrag
RUN chmod u=r,g=rw,o=rw /usr/local/share/metfrag-2.4.5-1/metfrag.jar
RUN ln -s /usr/local/share/metfrag-2.4.5-1/metfrag /usr/local/bin/

RUN chmod u=x,g=rx,o=rwx -R /usr/local/bin/run_metfrag.sh
RUN /bin/bash -c "source /opt/qt59/bin/qt59-env.sh"
ENV OPENMS_DATA_PATH=/usr/share/OpenMS
ENV QT_BASE_DIR=/opt/qt59
ENV QTDIR=$QT_BASE_DIR
ENV PATH=$QT_BASE_DIR/bin:$PATH
ENV LD_LIBRARY_PATH=$QT_BASE_DIR/lib/x86_64-linux-gnu:$QT_BASE_DIR/lib:$LD_LIBRARY_PATH
ENV PKG_CONFIG_PATH=$QT_BASE_DIR/lib/pkgconfig:$PKG_CONFIG_PATH


RUN /usr/bin/printf '\xfe\xed\xfe\xed\x00\x00\x00\x02\x00\x00\x00\x00\xe2\x68\x6e\x45\xfb\x43\xdf\xa4\xd9\x92\xdd\x41\xce\xb6\xb2\x1c\x63\x30\xd7\x92' > /etc/ssl/certs/java/cacerts
RUN /var/lib/dpkg/info/ca-certificates-java.postinst configure
