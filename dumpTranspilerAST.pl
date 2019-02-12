use File::Basename;
use File::stat;
use Time::localtime;

$needsToUpdate = 0; # false

$swiftFolder = "Sources/GryphonLib";
$astDumpFolder = "Bootstrap";

# Check if any file is outdated
opendir my $dir, $swiftFolder or die "🚨 Cannot open directory: $!";
my @allSourceFiles = readdir $dir;
closedir $dir;
my @swiftFiles = grep { $_ =~ /.*\.swift$/ } @allSourceFiles;
@swiftFiles = sort @swiftFiles;

opendir my $dir, $astDumpFolder or die "🚨 Cannot open directory: $!";
my @astDumpFiles = readdir $dir;
closedir $dir;
@astDumpFiles = grep { $_ =~ /.*\.swiftASTDump$/ } @astDumpFiles;
@astDumpFiles = sort @astDumpFiles;

if (scalar @astDumpFiles != scalar @swiftFiles) {
	print "Different number of swift files and AST dump files!\n";
	print "Needs to update.\n";
	$needsToUpdate = 1; # true
}
else {
	for (my $i=0; $i < scalar @astDumpFiles; $i++) {
		$swiftFilePath = $swiftFolder . "/" . @swiftFiles[$i];
		$astDumpFilePath = $astDumpFolder . "/" . @astDumpFiles[$i];

		# If the Swift file comes from a .gyb file, the .gyb file is the one that should be checked
		# for its modified date (since the Swift file it generates is modified in every compilation)
		my $gybFileName = @swiftFiles[$i];
		$gybFileName =~ s/(.*).swift/$1.swift.gyb/;
		if (grep { $_ eq $gybFileName} @allSourceFiles) { # If the gyb file exists
			$swiftFilePath = $swiftFolder . "/" . $gybFileName;
		}

		# If it's out of date
		if (-C $swiftFilePath < -C $astDumpFilePath) {
			print "Outdated file: $astDumpFilePath.\n";
			print "Needs to update.\n";
			$needsToUpdate = 1; # true
			last;
		}
	}
}

if ($needsToUpdate) {
	print "Calling the Swift compiler...\n";

	# Get the AST dumps and write them to the files
	my $output = `xcrun -toolchain org.swift.4220190203a swiftc Sources/GryphonLib/*.swift -dump-ast -module-name=ModuleName -output-file-map=output-file-map.json 2>&1`;

	# If the compilation failed (if the exit status isn't 0)
	if ($? != 0) {
		print "🚨 Error in the Swift compiler:\n";
		print "$output\n";
	}
	else {
		print "Done. Adding placeholders to AST dump files...\n";

		# Open the AST dump files and replace their contents where needed
		opendir my $dir, $astDumpFolder or die "🚨 Cannot open directory: $!";
		@astDumpFiles = readdir $dir;
		closedir $dir;
		@astDumpFiles = grep { $_ =~ /.*\.swiftASTDump$/ } @astDumpFiles;
		@astDumpFiles = sort @astDumpFiles;

		for (my $i=0; $i < scalar @astDumpFiles; $i++) {
			$swiftFilePath = $swiftFolder . "/" . @swiftFiles[$i];
			$astDumpFilePath = $astDumpFolder . "/" . @astDumpFiles[$i];

			my $contents;
			{
				local $/;
				open my $fh, '<', $astDumpFilePath or die "🚨 Could not open file '$astFilePath' $!";
				$contents = <$fh>;
			}

			print "Processing \"$astDumpFilePath\"...\n";

			# Replace file paths with placeholders
			while ($contents =~ s/$swiftFilePath/\<<testFilePath>>/) { }

			# Replace random memory addresses with placeholders
			while ($contents =~ s/0x[\da-f]+/<<memory address>>/) { }

			close $fh;


			# Write to the output file
			open(my $fh, '>', $astDumpFilePath) or die "🚨 Could not open file '$astDumpFilePath' $!";
			print $fh $contents;
			close $fh;
		}
	}
}
else {
	print "All files are up to date.\n";
}

print "Done!\n";
