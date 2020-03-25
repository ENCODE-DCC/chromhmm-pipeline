const request = require('request');
const qs = require('querystring');

module.exports = {
	assay: searchAssay,
	control: getControl,
	experiments: getExperiments
};

function searchAssay(assay) {
	return new Promise((resolve, reject) => {
		var list = [];
		request.get(
			"https://www.encodeproject.org/search/?" + qs.stringify({
				type: "Experiment",
				status: "released",
				assembly: "GRCh38",
				'target.label': assay,
				format: "json",
				limit: "all"
			}),
			{ json: true },
			(err, res, body) => {
				if (err) {
					console.error(err);
					reject(err);
					return;
				}
				var list = body["@graph"].map((item) => {
					return item.accession;
				});
				resolve(list);
			})
	});
}

function getControl(experiment) {
	return new Promise(function (resolve, reject) {
		request.get(
			`https://www.encodeproject.org/experiments/${experiment}/?format=json&limit=all`,
			{ json: true },
			function (error, res, body) {
				if (!error && res.statusCode == 200) {
					resolve(body.possible_controls.map((item) => item.accession));
				} else {
					console.error(JSON.stringify(res));
					reject(error);
				}
			});
	});
}

//data process in the resolve
function getExperiments(control) {
	return new Promise(function (resolve, reject) {
		request.get(
			"https://www.encodeproject.org/search/?" + qs.stringify({
				type: "Experiment",
				["possible_controls.accession"]: control,
				format: "json",
				limit: "all"
			}),
			{ json: true },
			function (error, res, body) {
				if (!error && res.statusCode == 200) {
					resolve(body);
				} else {
					console.error(JSON.stringify(res));
					reject(error);
				}
			});
	});
}