soft2gv.pl  --noorphans --sect-color=random --sect-outline\
  --tuples ElementList.csv,IsotopeList.csv,MoleculeList.csv \
  --styles ElementList.gvsty,IsotopeList.gvsty,MoleculeList.gvsty \
  --gvopts='rankdir=BT;dpi=72' --output=compounds.gv \
  chem_compounds.soft && \
  dot -Tpdf -o compounds.pdf compounds.gv
