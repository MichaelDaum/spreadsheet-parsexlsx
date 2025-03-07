package Spreadsheet::ParseXLSX::Decryptor::Agile;

use strict;
use warnings;

# VERSION

# ABSTRACT: decryptor for files of version 4.4

use base 'Spreadsheet::ParseXLSX::Decryptor';

sub decrypt {
  my $self = shift;
  my ($encryptedValue, $blockKey) = @_;

  my $key = $self->_generateDecryptionKey($blockKey);
  my $iv = $self->_generateInitializationVector('', $self->{blockSize});
  my $cbc = Crypt::Mode::CBC->new($self->{cipherAlgorithm}, 0);
  return $cbc->decrypt($encryptedValue, $key, $iv);
}

sub _generateDecryptionKey {
  my $self = shift;
  my ($blockKey) = @_;

  my $hash;

  unless ($self->{pregeneratedKey}) {
    $hash = $self->{hashProc}->($self->{salt} . Encode::encode('UTF-16LE', $self->{password}));
    for (my $i = 0 ; $i < $self->{spinCount} ; $i++) {
      $hash = $self->{hashProc}->(pack('L<', $i) . $hash);
    }
    $self->{pregeneratedKey} = $hash;
  }

  $hash = $self->{hashProc}->($self->{pregeneratedKey} . $blockKey);

  if (length($hash) > $self->{keyLength}) {
    $hash = substr($hash, 0, $self->{keyLength});
  } elsif (length($hash) < $self->{keyLength}) {
    $hash .= "\x36" x ($self->{keyLength} - length($hash));
  }
  return $hash;
}

sub _generateInitializationVector {
  my $self = shift;
  my ($blockKey, $blockSize) = @_;

  my $iv;
  if ($blockKey) {
    $iv = $self->{hashProc}->($self->{salt} . $blockKey);
  } else {
    $iv = $self->{salt};
  }

  if (length($iv) > $blockSize) {
    $iv = substr($iv, 0, $blockSize);
  } elsif (length($iv) < $blockSize) {
    $iv = $iv . ("\x36" x ($blockSize - length($iv)));
  }

  return $iv;
}

sub decryptFile {
  my $self = shift;
  my ($inFile, $outFile, $bufferLength, $key, $fileSize) = @_;

  my $cbc = Crypt::Mode::CBC->new($self->{cipherAlgorithm}, 0);

  my $inbuf;
  my $i = 0;

  while (($fileSize > 0) && (my $inlen = $inFile->read($inbuf, $bufferLength))) {
    my $blockId = pack('L<', $i);

    my $iv = $self->_generateInitializationVector($blockId, $self->{blockSize});

    if ($inlen < $bufferLength) {
      $inbuf .= "\x00" x ($bufferLength - $inlen);
    }

    my $outbuf = $cbc->decrypt($inbuf, $key, $iv);
    if ($fileSize < $inlen) {
      $inlen = $fileSize;
    }

    $outFile->write($outbuf, $inlen);
    $i++;
    $fileSize -= $inlen;
  }
}

sub verifyPassword {
  my $self = shift;
  my ($encryptedVerifier, $encryptedVerifierHash, $hashSize) = @_;

  my $encryptedVerifierHash0 = $self->{hashProc}->($self->decrypt($encryptedVerifier, "\xfe\xa7\xd2\x76\x3b\x4b\x9e\x79"));
  $encryptedVerifierHash = $self->decrypt($encryptedVerifierHash, "\xd7\xaa\x0f\x6d\x30\x61\x34\x4e");
  $encryptedVerifierHash0 = substr($encryptedVerifierHash0, 0, $hashSize);
  $encryptedVerifierHash = substr($encryptedVerifierHash, 0, $hashSize);

  die "Wrong password: $self" unless ($encryptedVerifierHash0 eq $encryptedVerifierHash);
}

=begin Pod::Coverage

  decrypt
  decryptFile
  verifyPassword

=end Pod::Coverage

=cut

1;
