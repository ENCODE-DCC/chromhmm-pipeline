const request = require('request');
const qs = require('querystring');

module.exports = {
	read_accession: read_accession,
	read_encode: read
}

//making 2 requests here, more efficient than letting portal redirect me though (1 second-ish vs 10)
// assuming  that accession is legal
async function read_accession(accession) {
	return new Promise((resolve, reject) => {
		read(
			"/search/?" + qs.stringify({
				searchTerm: accession,
				format: "json",
			})
		).then(
			// searched by accession up top, so dont need to verify stuff
			(search) => {
				read(search["@graph"][0]["@id"] + "?format=json").then(
					(result) => { resolve(result) },//  maybe add error checking here (check  to  see if search[graph][0][id] contains target accession)
					(err) => { reject(err) }
				)
			},
			(err) => { reject(err) }
		)
	});
}

async function read(uri) {
	return new Promise((resolve, reject) => {
		request.get(
			"https://www.encodeproject.org" + uri,
			{ format: "json" },
			(err, res, body) => {
				if (err) {
					reject(err);
					return;
				}
				resolve(JSON.parse(body))
			}
		)
	});
}