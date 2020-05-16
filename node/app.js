const utils = require("./util.js");
const cfg = require('./config.json')
const fs = require('fs');
const targetDataset = process.argv[2] || process.exit(1);

async function build_accession_graph(reference_epigenome_accession) {
	return new Promise((resolve, reject) => {
		var out = [];
		var need = 0;
		utils.read_accession(reference_epigenome_accession).then(
			(success) => {
				var filtered_accession = success["related_datasets"]
					.filter((val) => {
						return (
							// can ignore control here because we find that from assays
							// val.assay_title == "Control ChIP-seq" || 
							val.target && val.target.label && (cfg.assays.includes(val.target.label) || cfg.assays.length == 0)
						)
					})
					.map((val) => {
						return {
							label: val.target.label,
							accession: val.accession,
							title: val.assay_title
						}
					})
				filtered_accession.map((val) => {
					// do this for each accession, need to handle the number of outs
					utils.read_accession(val.accession).then(
						(data) => {
							var signals = data.files
								.filter((val) => { return val.assembly == "GRCh38" && val.output_type == "signal p-value" && val.biological_replicates.length == 1 })
							// console.error(signals)
							for (var s in signals) {
								need++;
								// console.error(need);
								var signal = signals[s]
								utils.read_accession(signal.accession).then(
									(success) => {
										out.push({
											mark: success.target.label,
											derived: success.derived_from,
											file: success.accession,
											replicate: success.biological_replicates[0] // there should only be one here, run error checking if issue arises, but also filtered on line  29
										})
										if (out.length >= need) {
											resolve(out)
										}
									},
									(fail) => (reject(fail))
								)
							}
						},
						(fail) => (reject(fail))

					)

				})

			},
			(fail) => (reject(fail))
		)

	});
}

/** signal: takes in one element from the accession graph method output array */
async function pair_files(signal) {
	return new Promise((resolve, reject) => {
		var download = {}
		var i = 1;
		var accession;
		var control_accession;
		for (var d in signal.derived) {
			i++
			utils.read_encode(signal.derived[d] + "?format=json").then(
				(success) => {
					if (success.biological_replicates == signal.replicate) { // this may change by this point, since this is async
						if (success.target && success.target.label)
							accession = success.accession
						else
							control_accession = success.accession
						if (!download[success.accession]) {
							download[success.accession] = success["s3_uri"]
						}
					}
					i--;
					if (i == 0) {
						resolve({
							replicate: signal.replicate,
							mark: signal.mark,
							accession: accession,
							control_accession: control_accession,
							download: download
						})
					}
				},
				(fail) => { reject(fail) }
			)
		}
		i--;
		if (i == 0) {
			resolve({
				replicate: signal.replicate,
				mark: signal.mark,
				accession: accession,
				control_accession: control_accession,
				download: download
			})
		}
	})
}


build_accession_graph(targetDataset).then(
	(success) => {
		var markTable = ""
		var download = {};
		var k = 1;
		for (var s in success) {
			k++
			var l = success[s];
			pair_files(l).then(
				(data) => {
					markTable += `cell${data.replicate}\t${data.mark}\t${data.accession}.bam\t${data.control_accession}.bam\n`
					var d = data.download;
					for (var i in d) {
						if (!download[i]) {
							download[i] = d[i];
						}
					}
					// this promise has returned
					k--;
					if (k == 0) {
						write_markTable_and_downloadScript(markTable, download)
					}
				},
				(fail) => { console.error(fail) }
			)
		}
		k--;
		if (k == 0) {
			write_markTable_and_downloadScript(markTable, download)
		}
	},
	(fail) => { console.error(fail) }
)
function write_markTable_and_downloadScript(markTable, download) {
	fs.writeFileSync(`${targetDataset}.markTable`, markTable);
	var d = [];
	for (var e in download) {
		d.push(download[e])
	}
	fs.writeFileSync(`${targetDataset}.json`, JSON.stringify({
		["chromhmm.bams"]: d
		
	}));
}

console.log(`cat ${targetDataset}.markTable | sort | uniq > ${targetDataset}.marktable2 && rm ${targetDataset}.markTable && cat ${targetDataset}.marktable2 | grep undefined.bam`)
console.log(`gsutil mv ${targetDataset}.marktable2 gs://chromhmm-inputs/${targetDataset}/markTable.KS & mv ${targetDataset}-KS.json ../inputs/`)


// Assays
// "H3K27ac",
// "H3K27me3",
// "H3K36me3",
// "H3K4me1",
// "H3K4me3",
// "H3K9me3"

// Datasets
// Stomach: ENCSR840QYF
// Sigmoid colon: ENCSR816KBS
// Transverse Colon: ENCSR654ORD
// Upper Lobe of Left Lung: ENCSR191PVZ
// Spleen: ENCSR211RGU
// H1: ENCSR938GXK
// IMR-90: ENCSR596VTT
// H9: ENCSR673EAQ
// A549: ENCSR706RZK
// SK-N-SH: ENCSR256OEH