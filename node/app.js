async function main() {
	const search = require('./search')
	const { assays } = require('./config.json');
	var outputArrays = [];
	for (var a in assays) {
		outputArrays.push(await searchAssay(assays[a]));
		// console.error(a)
	}
	var experiments = merge(outputArrays);
	//search for the controls
	// var tmp = experiments.map((val) => getControl(val))
	var out = []
	//let the searches resolve
	for (var i in experiments) {
		console.error(i)
		var controls = await getControl(experiments[i]);
		for (var c in controls) {
			var control = controls[c]
			if (!out[control]) {
				var tmp = await getExperiments(control)
				out[control] = tmp["@graph"].reduce((prev, curr, index) => {

				});
				// console.log(JSON.stringify(out[control]["@graph"].map((val) => val.accession)));
			}
		}
	}
	return out;
}

main(); i