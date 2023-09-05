const express = require('express');
const app = express();

app.get('/', (req,res)=>{
	res.send("Project: Clouddev Development for Cloudair");
});

app.listen(80, function () {
	console.log("Testing Clouddev web app on port 80");
});
