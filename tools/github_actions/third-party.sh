#!/usr/bin/env bash
# This install script is used in our GitHub Actions CI.
# See .github/workflows/ci.yml

set -e

# Use the THIRD_PARTY_DIR environment variable set by the workflow.
if [ -z "$THIRD_PARTY_DIR" ]; then
    echo "Error: THIRD_PARTY_DIR environment variable is not set."
    exit 1
fi

# Installing the third-party software and the appropriate env variables.
pushd "$THIRD_PARTY_DIR" 2>/dev/null || { mkdir -p "$THIRD_PARTY_DIR"; pushd "$THIRD_PARTY_DIR"; }

# usage: sha256_ok <sha256> <file>. macOS 15+ ships Apple's own sha256sum, which
# reads the check line from stdin only when given "-" and, without --strict, skips
# a malformed line (an empty hash, say) and exits 0. Older macOS has only shasum.
sha256_ok() {
    if command -v sha256sum >/dev/null; then
        echo "$1  $2" | sha256sum --strict -c -
    else
        echo "$1  $2" | shasum -a 256 --strict -c -
    fi
}

# usage: fetch_verified <file> <sha256> <url>... Saves the first download that
# matches the sha256, so a fallback source can never swap in other bytes.
fetch_verified() {
    local file_name="$1" sha256="$2" url
    shift 2
    for url in "$@"; do
        # bounded so an unreachable host (134 s per attempt on runners, see 1e134feb7)
        # or a stalled transfer can't hold up the next source for long
        if curl -fL --retry 5 --retry-all-errors --connect-timeout 30 --speed-limit 1024 --speed-time 60 \
            "$url" -o "$file_name" && sha256_ok "$sha256" "$file_name"; then
            return 0
        fi
        echo "No verified ${file_name} from ${url}" >&2
    done
    return 1
}

stanford_downloads="https://downloads.cs.stanford.edu/nlp/software"
# 302s each zip to stanford_downloads, kept in case Stanford moves the files
stanford_redirector="https://nlp.stanford.edu/software"

# Download nltk stanford dependencies
# Downloaded to $THIRD_PARTY_DIR/stanford-corenlp
# stanford_corenlp_package_zip_name=$(curl -s 'https://stanfordnlp.github.io/CoreNLP/' | grep -o 'stanford-corenlp-full-.*\.zip' | head -n1)
stanford_corenlp_package_zip_name="stanford-corenlp-4.5.1.zip"
stanford_corenlp_sha256="7d6f9d01a595d0f783ce805b9c32bcc8789cd2f299de719b2c71801bbd88605b"
[[ ${stanford_corenlp_package_zip_name} =~ (.+)\.zip ]]
stanford_corenlp_package_name=${BASH_REMATCH[1]}
if [[ ! -d "${stanford_corenlp_package_name}" ]]; then
    # the Hugging Face URL is pinned to the commit that added 4.5.1
    fetch_verified "${stanford_corenlp_package_zip_name}" "${stanford_corenlp_sha256}" \
        "${stanford_downloads}/${stanford_corenlp_package_zip_name}" \
        "https://huggingface.co/stanfordnlp/CoreNLP/resolve/6d357652fa33f61b7ebf8d5b2afafdb22f1df323/stanford-corenlp-latest.zip" \
        "${stanford_redirector}/${stanford_corenlp_package_zip_name}"
    unzip -q "${stanford_corenlp_package_zip_name}"
    rm "${stanford_corenlp_package_zip_name}"
    mv "${stanford_corenlp_package_name}" 'stanford-corenlp'
fi

# Downloaded to $THIRD_PARTY_DIR/stanford-parser
# stanford_parser_package_zip_name=$(curl -s 'https://nlp.stanford.edu/software/lex-parser.shtml' | grep -o 'stanford-parser-full-.*\.zip' | head -n1)
stanford_parser_package_zip_name="stanford-parser-full-2018-10-17.zip"
stanford_parser_sha256="92d852af54c0727c2367b9ce267c53bf08f1551a08ec5dd92c357b8cc7b2bcd9"
[[ ${stanford_parser_package_zip_name} =~ (.+)\.zip ]]
stanford_parser_package_name=${BASH_REMATCH[1]}
if [[ ! -d "${stanford_parser_package_name}" ]]; then
    fetch_verified "${stanford_parser_package_zip_name}" "${stanford_parser_sha256}" \
        "${stanford_downloads}/${stanford_parser_package_zip_name}" \
        "${stanford_redirector}/${stanford_parser_package_zip_name}"
    unzip -q "${stanford_parser_package_zip_name}"
    rm "${stanford_parser_package_zip_name}"
    mv "${stanford_parser_package_name}" 'stanford-parser'
fi

# Downloaded to $THIRD_PARTY_DIR/stanford-postagger
# stanford_tagger_package_zip_name=$(curl -s 'https://nlp.stanford.edu/software/tagger.shtml' | grep -o 'stanford-postagger-full-.*\.zip' | head -n1)
stanford_tagger_package_zip_name="stanford-postagger-full-2018-10-16.zip"
stanford_tagger_sha256="daae101e62315aedcb26d75710c2898879149933b56181c00b2f00903b31eb33"
[[ ${stanford_tagger_package_zip_name} =~ (.+)\.zip ]]
stanford_tagger_package_name=${BASH_REMATCH[1]}
if [[ ! -d "${stanford_tagger_package_name}" ]]; then
    fetch_verified "${stanford_tagger_package_zip_name}" "${stanford_tagger_sha256}" \
        "${stanford_downloads}/${stanford_tagger_package_zip_name}" \
        "${stanford_redirector}/${stanford_tagger_package_zip_name}"
    unzip -q "${stanford_tagger_package_zip_name}"
    rm "${stanford_tagger_package_zip_name}"
    mv "${stanford_tagger_package_name}" 'stanford-postagger'
fi

# Download SENNA to $THIRD_PARTY_DIR/senna
# senna_file_name=$(curl -s 'https://ronan.collobert.com/senna/download.html' | grep -o 'senna-v.*.tgz' | head -n1)
if [[ "$(uname -s)" == "Linux" ]]; then
    senna_file_name=$(curl -s 'https://ronan.collobert.com/senna/download.html' | grep -o 'senna-v.*.tgz' | head -n1)
    senna_folder_name='senna'
    if [[ ! -d "${senna_folder_name}" ]]; then
        curl -L "https://ronan.collobert.com/senna/$senna_file_name" -o "${senna_file_name}"
        # wget -nv "https://ronan.collobert.com/senna/$senna_file_name"
        tar -xzf "${senna_file_name}"
        rm "${senna_file_name}"
    fi
else
    echo "Skipping SENNA download on $(uname -s)"
fi

# Download PROVER9 to $THIRD_PARTY_DIR/prover9
if [[ "$(uname -s)" == "Linux" ]]; then
    prover9_file_name="p9m4-v05.tar.gz"
    [[ ${prover9_file_name} =~ (.+)\.tar\.gz ]]
    prover9_folder_name=${BASH_REMATCH[1]}
    if [[ ! -d "${prover9_folder_name}" ]]; then
        curl -L "https://www.cs.unm.edu/~mccune/prover9/gui/$prover9_file_name" -o "${prover9_file_name}"
        tar -xzf "${prover9_file_name}"
        mv "${prover9_folder_name}" 'prover9'
        rm "${prover9_file_name}"
    fi
else
    echo "Skipping PROVER9 download on $(uname -s)"
fi

# Download MEGAM to $THIRD_PARTY_DIR/megam. hal3.name only redirects to the
# author's University of Maryland host, which some runners cannot reach via
# the redirector, so fetch there directly and check the sha256 (CWE-494).
if [[ "$(uname -s)" == "Linux" ]]; then
    megam_file_name="megam_i686.opt.gz"
    megam_sha256="ed2b00f425afb649b796beb25a016311b9a6586d176bcb4de31cb6468bf3a31d"
    [[ ${megam_file_name} =~ (.+)\.gz ]]
    megam_folder_name=${BASH_REMATCH[1]}
    if [[ ! -d "${megam_folder_name}" ]]; then
        curl -fL --retry 5 --retry-all-errors "https://users.umiacs.umd.edu/~hal3/megam/$megam_file_name" -o "${megam_file_name}"
        echo "${megam_sha256}  ${megam_file_name}" | sha256sum -c
        gunzip -vf "${megam_file_name}"
        mkdir -p "megam"
        mv "${megam_folder_name}" "megam/${megam_folder_name}"
        chmod -R 711 "megam/${megam_folder_name}"
    fi
else
    echo "Skipping MEGAM download on $(uname -s)"
fi

# Download Graphviz to $THIRD_PARTY_DIR/graphviz (Windows only: apt and brew
# install it on Linux and macOS). The portable zip comes from Graphviz's own
# release storage and is checked against its published sha256, so no package
# feed is in the loop (Chocolatey's answered 504 in 28 CI cells of 102 runs).
if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
    graphviz_version="16.1.0"
    graphviz_sha256="733e49626c492242eb8dca30ea627b6ead20710e207998c7933b4909d92d6abc"
    graphviz_file_name="windows_10_cmake_Release_Graphviz-${graphviz_version}-win64.zip"
    if [[ ! -d "graphviz" ]]; then
        curl -fL --retry 5 --retry-all-errors "https://gitlab.com/api/v4/projects/4207231/packages/generic/graphviz-releases/${graphviz_version}/${graphviz_file_name}" -o "${graphviz_file_name}"
        echo "${graphviz_sha256}  ${graphviz_file_name}" | sha256sum -c
        unzip -q "${graphviz_file_name}"
        rm "${graphviz_file_name}"
        mv "Graphviz-${graphviz_version}-win64" 'graphviz'
    fi
else
    echo "Skipping Graphviz download on $(uname -s)"
fi

# TADM requires `libtaopetsc.so` from PETSc v2.3.3, and likely has more
# tricky to install requirements, so we don't run tests for it.
# Download TADM to $THIRD_PARTY_DIR/tadm
# tadm_file_name="tadm-0.9.8.tgz"
# [[ ${tadm_file_name} =~ (.+)\.tgz ]]
# tadm_folder_name=${BASH_REMATCH[1]}
# if [[ ! -d "${tadm_folder_name}" ]]; then
#     curl -L "https://master.dl.sourceforge.net/project/tadm/tadm/tadm%200.9.8/$tadm_file_name?viasf=1" -o "${tadm_file_name}"
#     tar -xvzf "${tadm_file_name}"
#     rm "${tadm_file_name}"
#     chmod -R 711 "./tadm/bin/tadm"
# fi

# Download MaltParser to $THIRD_PARTY_DIR/maltparser
# malt_file_name=$(curl -s 'http://maltparser.org/download.html' | grep -o 'maltparser-.*\.tar.gz' | head -n1)
malt_file_name="maltparser-1.9.2.tar.gz"
[[ ${malt_file_name} =~ (.+)\.tar\.gz ]]
malt_folder_name=${BASH_REMATCH[1]}
if [[ ! -d "${malt_folder_name}" ]]; then
    curl -L "http://maltparser.org/dist/$malt_file_name" -o "${malt_file_name}"
    tar -xzf "${malt_file_name}"
    mv "${malt_folder_name}" 'maltparser'
    rm "${malt_file_name}"
fi

ls -l "$THIRD_PARTY_DIR"

popd
