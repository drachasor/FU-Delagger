TEMP = $(shell echo ${BRANCH_NAME} | sed -e "s/\//_/g")
TMP = $(shell cmp --silent "./FU_Delagger/_metadata" "/home/jenkins/FU_Factory_Delagger/oldFU_Factory_Delagger$(TEMP)metadata" && echo "1" || echo "0" )
Timestamp = $(shell date +"%Y-%m-%d_%H-%M-%S")

all: build
	@echo 'Finished'

changes:
	@if [ $(TMP) -eq 1 ]; then\
		echo "No need to build";\
	else\
		echo "Build needed";\
	fi
	
check:
	@cd FU_Delagger/
	@if test -e "./FU_Delagger/_metadata"; then\
		echo "metadata file found";\
	else\
		echo "Missing file : _metadata";\
		exit 1;\
	fi
	@if test -e "/home/jenkins/asset_packer"; then\
		echo "Asset packer found";\
	else\
		echo "Missing file : asset_packer";\
		exit 1;\
	fi

build: changes
	@cd FU_Delagger/
	@if [ $(TMP) -eq 0 ]; then\
		echo '***Building the $(TEMP) branch***';\
		mv /home/jenkins/Dropbox/FU_Factory_Delagger/FU_Factory_Delagger_$(TEMP).zip /home/jenkins/Dropbox/FU_Factory_Delagger/previousVersions/FU_Factory_Delagger_$(TEMP)_$(Timestamp).zip ;\
		mv /home/jenkins/Dropbox/FU_Factory_Delagger/FU_Factory_Delagger_$(TEMP).pak /home/jenkins/Dropbox/FU_Factory_Delagger/previousVersions/FU_Factory_Delagger_$(TEMP)_$(Timestamp).pak ;\
		cp ./_metadata /home/jenkins/FU_Factory_Delagger/oldFU_Factory_Delagger$(TEMP)metadata;\
		echo "***Previous version was moved out of the way***";\
		zip -r9 ../FU_Factory_Delagger_$(TEMP).zip ./* -x *.git* Makefile Jenkinsfile README.md *.zip *.pak ;\
		cp ../FU_Factory_Delagger_$(TEMP).zip /home/jenkins/Dropbox/FU_Factory_Delagger/FU_Factory_Delagger_$(TEMP).zip;\
		echo '***Zip archive done. Preparing the pak files***';\
		mkdir ../temporaryBuildFolder;\
		rsync -a --progress . ../temporaryBuildFolder --exclude .git --exclude Jenkinsfile --exclude Makefile --exclude README.md --exclude "*.zip" --exclude "*.pak";\
		echo '***Temporary folder prepared. Building the pak file***';\
		/home/jenkins/asset_packer ../temporaryBuildFolder /home/jenkins/Dropbox/FU_Factory_Delagger/FU_Factory_Delagger_$(TEMP).pak;\
		echo '***Pak file done. Cleaning***';\
		rm -f ../FU_Factory_Delagger_$(TEMP).zip;\
		rm -fr ../temporaryBuildFolder;\
		echo '***Built***';\
	fi

