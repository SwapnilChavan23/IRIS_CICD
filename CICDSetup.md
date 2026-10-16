# Project Scope

The scope of this project is to configure a CI/CD pipeline setup for my locally running instances of Intersystems IRIS HealthConnect DEV and TEST so I can perform seamless deployments of interfaces/interface updates between DEV and TEST environments. 
For source control, I am making use of GitHub for which the GitHub MCP server setup is completed. 
I already have the instances of DEV and TEST Intersystems HealthConnect up and running locally.
I would like to make use of VSCode and git bash commands for deployments so it would be helpful to configure everything accordingly.
Dev instance is where all the developments will be done and I would then commit changes, add a commit message before pushing them to TEST for testing.

## Current Setup

/home/DEV_Git - Is the folder where the branch of dev repo is setup. The name on GitHub for this repo is Local_Dev
/home/TEST_Git - Is the folder where we need to setup the test branch for test repo. Name it as Local_Test on GitHub

## Local Instances

Below is the information about locally running instances of IRIS - 

Dev instance is running on Port - 52773
Test instance is running on Port - 52774

Configuration 'DEV'   (default)
	directory:    /opt/Intersystems/IRISDEV
	versionid:    2026.1.0.235.2com
	datadir:      /opt/Intersystems/IRISDEV
	conf file:    iris.cpf  (WebServer port = 52773)
	status:       running, since Sun Aug 30 12:14:29 2026
	SuperServers: 1972
	state:        warn
	product:      InterSystems IRISHealth

Configuration 'TEST'
	directory:    /opt/Intersystems/IRISTEST
	versionid:    2026.1.0.235.2com
	datadir:      /opt/Intersystems/IRISTEST
	conf file:    iris.cpf  (WebServer port = 52774)
	status:       running, since Sun Aug 30 12:14:35 2026
	SuperServers: 51773
	state:        warn
	product:      InterSystems IRISHealth


## Summarize

Post completing all the setup, create a brief summary document that provide stepwise instructions of the task performed for setting up CI/CD pipeline.
Save all this in a new file under the project folder named "Instructions.md"
