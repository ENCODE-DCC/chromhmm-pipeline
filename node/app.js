async function build_accession_graph(reference_epigenome_accession) {
	return new Promise((resolve, reject) => {
		var out = [];
		const utils = require("./util.js");
		const cfg = require('./config.json')
		utils.read_accession(reference_epigenome_accession).then(
			(success) => {
				var filtered_accession = success["related_datasets"]
					.filter((val) => {
						return (
							// can ignore control here because we find that from assays
							// val.assay_title == "Control ChIP-seq" || 
							val.target && val.target.label && cfg.assays.includes(val.target.label))

					})
					.map((val) => {
						return {
							label: val.target.label,
							accession: val.accession,
							title: val.assay_title
						}
					})
				filtered_accession.map((val) => {
					// do this for each accession
					utils.read_accession(val.accession).then(
						(data) => {
							var signal = data.files
								.filter((val) => { return val.assembly == "GRCh38" && val.output_type == "signal p-value" })[0]
							utils.read_accession(signal.accession).then(
								(success) => {
									out.push({
										mark: val.label,
										derived: success.derived_from
									})
									if (out.length >= filtered_accession.length) {
										resolve(out)
									}
								},
								(fail) => (reject(fail))
							)

						},
						(fail) => (reject(fail))

					)

				})

			},
			(fail) => (reject(fail))
		)

	});
}




build_accession_graph("ENCSR840QYF").then(
	(success) => { console.log(JSON.stringify(success)) },
	(fail) => { console.error(fail) }
)