use strict;
use warnings;
use Test::More;
use Spreadsheet::ParseXLSX;

# Define test XLSX files
my @test_files = (
    { file => 't/data/author_single.xlsx',   expected => 'Alexander Becker' },
    { file => 't/data/author_multiple.xlsx', expected => 'Alexander Becker;Test2' },
    { file => 't/data/author_none.xlsx',       expected => undef },
    { file => 't/data/author_invalid_core.xlsx',       expected => undef },
);

# Test each file
foreach my $test (@test_files) {
    my $parser   = Spreadsheet::ParseXLSX->new();
    my $workbook = $parser->parse($test->{file});

    if (defined $test->{expected}) {
        ok($workbook->{Author}, "Author extracted for $test->{file}");
        is($workbook->{Author}, $test->{expected}, "Correct author for $test->{file}");
    } else {
        ok(!defined $workbook->{Author}, "No author extracted for $test->{file}");
    }
}

done_testing();
