soft2gv.pl  --noorphans --sect-color=random --nosect-outline\
  --tuples ElementList.csv,IsotopeList.csv,MoleculeList.csv \
  --styles ElementList.gvsty,IsotopeList.gvsty,MoleculeList.gvsty \
  --gvopts='rankdir=LR;dpi=72' --output=chem.gv \
  chem_elements.soft && \
  dot -Tpdf -o chem.pdf chem.gv
