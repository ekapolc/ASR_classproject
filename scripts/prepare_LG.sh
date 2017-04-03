#!/bin/bash

set +x

# Copyright 2014 Vassil Panayotov
# Apache 2.0
# Modified by Ekapol Chuangsuwanich for ASR class

# Prepares the dictionary and add required silence tokens


. utils/parse_options.sh || exit 1;
. path.sh || exit 1


if [ $# -ne 5 ]; then
  echo "Usage: $0 [options] <lexicon_raw_nosil> <lm_arpa> <phonelist> <dict_out_dir> <lang_out_dir>"
  echo "e.g.: $0 lexicon.txt data/local/dict"
  exit 1
fi

lexicon_raw_nosil=$1
lm=$2
phonelist=$3
dict_out_dir=$4
lang_out_dir=$5

[ -d $dict_out_dir ] && echo "$0: output $dict_out_dir directory exists. Please remove before starting" && exit 1;
[ -d $lang_out_dir ] && echo "$0: output $lang_out_dir directory exists. Please remove before starting" && exit 1;
[ ! -f $lexicon_raw_nosil ] && echo "$0: lexicon file not found at $lexicon_raw_nosil" && exit 1;

mkdir -p $dict_out_dir || exit 1;
mkdir -p $lang_out_dir || exit 1;


silence_phones=$dict_out_dir/silence_phones.txt
optional_silence=$dict_out_dir/optional_silence.txt
nonsil_phones=$dict_out_dir/nonsilence_phones.txt
extra_questions=$dict_out_dir/extra_questions.txt

echo "Preparing phone lists and clustering questions"
(echo SIL; ) > $silence_phones
echo SIL > $optional_silence

# add a special word that contains every phoneme so that hclg builds correctly
cp $lexicon_raw_nosil /tmp/tmplex

# nonsilence phones; on each line is a list of phones that correspond
# really to the same base phone.
awk '{for (i=2; i<=NF; ++i) { print $i; gsub(/[0-9]/, "", $i); print $i}}' $lexicon_raw_nosil |\
  sort -u |\
  perl -e 'while(<>){
    chop; m:^([^\d]+)(\d*)$: || die "Bad phone $_";
    $phones_of{$1} .= "$_ "; }
    foreach $list (values %phones_of) {print $list . "\n"; } ' \
    > $nonsil_phones || exit 1;
# A few extra questions that will be added to those obtained by automatically clustering
# the "real" phones.  These ask about stress; there's also one for silence.
cat $silence_phones| awk '{printf("%s ", $1);} END{printf "\n";}' > $extra_questions || exit 1;
cat $nonsil_phones | perl -e 'while(<>){ foreach $p (split(" ", $_)) {
  $p =~ m:^([^\d]+)(\d*)$: || die "Bad phone $_"; $q{$2} .= "$p "; } } foreach $l (values %q) {print "$l\n";}' \
  >> $extra_questions || exit 1;
echo "$(wc -l <$silence_phones) silence phones saved to: $silence_phones"
echo "$(wc -l <$optional_silence) optional silence saved to: $optional_silence"
echo "$(wc -l <$nonsil_phones) non-silence phones saved to: $nonsil_phones"
echo "$(wc -l <$extra_questions) extra triphone clustering-related questions saved to: $extra_questions"

(echo '!SIL SIL'; ) |\
cat - $lexicon_raw_nosil | sort | uniq >$dict_out_dir/lexicon.txt
echo "Lexicon text file saved as: $dict_out_dir/lexicon.txt"

utils/prepare_lang.sh --phone-symbol-table $phonelist $dict_out_dir '!SIL' $dict_out_dir/lang_tmp $lang_out_dir

[ -f $lm.gz ] && rm $lm.gz
gzip -k $lm
../../babel/s5/local/arpa2G.sh $lm.gz $lang_out_dir $lang_out_dir

exit 0;
