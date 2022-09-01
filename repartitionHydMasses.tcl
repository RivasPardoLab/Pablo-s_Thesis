# Author: Jeff Comer <jeffcomer at gmail>
#source $env(HOME)/scripts/useful.tcl
#vmdargs repartitionMasses psf pdb massScale selText outPsf

mol new ionized.psf
mol addfile ionized.pdb


set sel [atomselect top "protein and hydrogen"]
#puts "Repartitioning mass of [$sel num] hydrogen atoms."

foreach bondList [$sel getbonds] hi [$sel get index] {
    # Get the current mass.
    set hydSel [atomselect top "index $hi"]
    set hydMass [$hydSel get mass]
    set newMass [expr {3.0*$hydMass}]
    set delMass [expr {$newMass - $hydMass}]

    if {$hydMass > 1.5} {
	puts "WARNING: Current hydrogen mass $hydMass, new hydrogen mass $newMass. Maybe repartitioning was previously done?"
    }

    # Get the new masses of heavy bonded atoms.
    set s [atomselect top "index $bondList and noh"]
    set massList {}
    set n [$s num]
    foreach m [$s get mass] {
	lappend massList [expr {$m - $delMass/double($n)}]
    }

    # Set the new masses.
    $hydSel set mass $newMass
    $s set mass $massList
    $s delete
    $hydSel delete
}

set all [atomselect top all]
$all writepsf ionized_REP.psf

$sel delete
$all delete
#exit
