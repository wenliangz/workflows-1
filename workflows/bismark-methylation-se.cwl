cwlVersion: v1.0
class: Workflow


'sd:upstream':
  genome:
    - "bismark-indices.cwl"


inputs:

  alias:
    type: string
    label: "Experiment short name/Alias"
    sd:preview:
      position: 1

  fastq_file:
    type: File
    format: "http://edamontology.org/format_1930"
    label: "FASTQ file"
    doc: "Uncompressed or gzipped FASTQ file, single-end"

  adapters_file:
    type: File
    format: "http://edamontology.org/format_1929"
    label: "Adapters file"
    doc: "FASTA file containing adapters"

  indices_folder:
    type: Directory
    label: "Bismark indices folder"
    doc: "Path to Bismark generated indices folder"
    'sd:upstreamSource': "genome/indices_folder"

  threads:
    type: int?
    default: 1
    label: "Number of cores to use"
    doc: "Sets the number of parallel instances of Bismark to be run concurrently"
    'sd:layout':
      advanced: true


outputs:

  bismark_align_log_file:
    type: File
    label: "Bismark aligner log file"
    doc: "Log file generated by Bismark on the alignment step"
    format: "http://edamontology.org/format_2330"
    outputSource: bismark_align/log_file

  chg_context_file:
    type: File
    label: "CHG methylation call"
    doc: "CHG methylation call"
    format: "http://edamontology.org/format_3475"
    outputSource: bismark_extract_methylation/chg_context_file

  chh_context_file:
    type: File
    label: "CHH methylation call"
    doc: "CHH methylation call"
    format: "http://edamontology.org/format_3475"
    outputSource: bismark_extract_methylation/chh_context_file

  cpg_context_file:
    type: File
    label: "CpG methylation call"
    doc: "CpG methylation call"
    format: "http://edamontology.org/format_3475"
    outputSource: bismark_extract_methylation/cpg_context_file

  mbias_plot:
    type: File
    label: "Methylation bias plot"
    doc: "QC data showing methylation bias across read lengths"
    format: "http://edamontology.org/format_3475"
    outputSource: bismark_extract_methylation/mbias_plot

  bedgraph_cov_file:
    type: File
    label: "Methylation statuses in bedGraph format"
    doc: "Methylation statuses in bedGraph format"
    format: "http://edamontology.org/format_3583"
    outputSource: bismark_extract_methylation/bedgraph_cov_file

  bismark_cov_file:
    type: File
    label: "Genome-wide cytosine methylation report"
    doc: "Coverage text file summarising cytosine methylation values"
    format: "http://edamontology.org/format_3583"
    outputSource: bismark_extract_methylation/bismark_cov_file

  splitting_report_file:
    type: File
    label: "Methylation extraction log"
    doc: "Log file giving summary statistics about methylation extraction"
    format: "http://edamontology.org/format_2330"
    outputSource: bismark_extract_methylation/splitting_report_file


steps:

  trim_adapters:
    run: ../tools/trimmomatic.cwl
    in:
      fastq_file_upstream: fastq_file
      adapters_file: adapters_file
      lib_type:
        default: "SE"
      illuminaclip_step_param:
        default: "2:30:10"
      leading_step:
        default: 30
      trailing_step:
        default: 30
      sliding_window_step:
        default: "5:30"
      minlen_step:
        default: 25
      threads: threads
    out: [upstream_trimmed_file]

  bismark_align:
    run: ../tools/bismark-align.cwl
    in:
      fastq_file: trim_adapters/upstream_trimmed_file
      indices_folder: indices_folder
      threads: threads
    out: [bam_file, log_file]

  bismark_extract_methylation:
    run: ../tools/bismark-extract-methylation.cwl
    in:
      genome_folder: indices_folder
      bam_file: bismark_align/bam_file
      threads: threads
    out:
      - chg_context_file
      - chh_context_file
      - cpg_context_file
      - mbias_plot
      - bedgraph_cov_file
      - bismark_cov_file
      - splitting_report_file


$namespaces:
  s: http://schema.org/

$schemas:
- http://schema.org/docs/schema_org_rdfa.html

s:name: "bismark-methylation"
s:downloadUrl: https://github.com/Barski-lab/workflows/blob/master/workflows/bismark-methylation.cwl
s:codeRepository: https://github.com/Barski-lab/workflows
s:license: http://www.apache.org/licenses/LICENSE-2.0

s:isPartOf:
  class: s:CreativeWork
  s:name: Common Workflow Language
  s:url: http://commonwl.org/

s:creator:
- class: s:Organization
  s:legalName: "Cincinnati Children's Hospital Medical Center"
  s:location:
  - class: s:PostalAddress
    s:addressCountry: "USA"
    s:addressLocality: "Cincinnati"
    s:addressRegion: "OH"
    s:postalCode: "45229"
    s:streetAddress: "3333 Burnet Ave"
    s:telephone: "+1(513)636-4200"
  s:logo: "https://www.cincinnatichildrens.org/-/media/cincinnati%20childrens/global%20shared/childrens-logo-new.png"
  s:department:
  - class: s:Organization
    s:legalName: "Allergy and Immunology"
    s:department:
    - class: s:Organization
      s:legalName: "Barski Research Lab"
      s:member:
      - class: s:Person
        s:name: Michael Kotliar
        s:email: mailto:michael.kotliar@cchmc.org
        s:sameAs:
        - id: http://orcid.org/0000-0002-6486-3898

doc: |
  Bismark Methylation pipeline.

s:about: |

  Sequence reads are first cleaned from adapters and transformed into fully bisulfite-converted forward (C->T) and reverse
  read (G->A conversion of the forward strand) versions, before they are aligned to similarly converted versions of the
  genome (also C->T and G->A converted). Sequence reads that produce a unique best alignment from the four alignment processes
  against the bisulfite genomes (which are running in parallel) are then compared to the normal genomic sequence and the
  methylation state of all cytosine positions in the read is inferred. A read is considered to align uniquely if an alignment
  has a unique best alignment score (as reported by the AS:i field). If a read produces several alignments with the same number
  of mismatches or with the same alignment score (AS:i field), a read (or a read-pair) is discarded altogether.

  On the next step we extract the methylation call for every single C analysed. The position of every single C will be written
  out to a new output file, depending on its context (CpG, CHG or CHH), whereby methylated Cs will be labelled as forward
  reads (+), non-methylated Cs as reverse reads (-). The output of the methylation extractor is then transformed into a bedGraph
  and coverage file. The bedGraph counts output is then used to generate a genome-wide cytosine report which reports the number
  on every single CpG (optionally every single cytosine) in the genome, irrespective of whether it was covered by any reads or not.
  As this type of report is informative for cytosines on both strands the output may be fairly large (~46mn CpG positions or >1.2bn
  total cytosine positions in the human genome).
