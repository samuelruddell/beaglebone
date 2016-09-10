#!/usr/bin/env node
/* This script copies js and css files to the appropriate directory to be served to the client */

var fs = require('fs')
var path = require('path')
var exec = require('child_process').exec

var cwd = process.cwd()
var js = path.join(cwd, 'client/js/')
var css = path.join(cwd, 'client/css/')
var paths = [ js, css ]

// make directory if it doesn't exist
for (var pathIndex in paths) {
	if(!fs.existsSync(paths[pathIndex])) {
		console.log("Creating directory: ", paths[pathIndex])
		fs.mkdirSync(paths[pathIndex]);
	}
}

// function to find and copy files from node_modules
function copyMinified(fileName,outDir,callback) {
	exec("find " + path.join(cwd,'node_modules/') + " -name " + fileName, function (err, stdout, stdin) {
		if (err) {
			console.log(err)
		} else if (stdout) {
			var inputFile = stdout.replace(/\s+/g,'')
			console.log("Copying " + fileName + " to " + outDir)
			fs.writeFile(path.join(outDir,fileName), fs.readFileSync(inputFile))
		} else {
			console.log("ERROR: Cannot find " + fileName + " in " + path.join(cwd,'node_modules/'))
		}
	});
}


// copy the files
copyMinified('bootstrap.min.js', js)
copyMinified('bootstrap.min.css', css)
copyMinified('jquery.min.js', js)
copyMinified('jquery.flot.js', js)
