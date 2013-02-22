use strict;
use warnings;
use Test::More;
use Test::Exception;

use MongoDB;
use Scalar::Util 'blessed';

my $conn;
eval {
    my $host = "localhost";
    if (exists $ENV{MONGOD}) {
        $host = $ENV{MONGOD};
    }
    $conn = MongoDB::MongoClient->new(host => $host, ssl => $ENV{MONGO_SSL});
};

if ($@) {
    plan skip_all => $@;
}
else {
    plan tests => 13;
}

{
    my $ref = MongoDB::DBRef->new( db => 'test', ref => 'test_coll', id => 123 );
    ok $ref;
    isa_ok $ref, 'MongoDB::DBRef';
}

# test type coercions 
{ 
    my $db   = $conn->get_database( 'test' );
    my $coll = $db->get_collection( 'test_collection' );

    my $ref = MongoDB::DBRef->new( db => $db, ref => $coll, id => 123 );

    ok $ref;
    ok not blessed $ref->db;
    ok not blessed $ref->ref;

    is $ref->db, 'test';
    is $ref->ref, 'test_collection';
    is $ref->id, 123;
}

# test fetch
{ 
    $conn->get_database( 'test' )->get_collection( 'test_coll' )->insert( { _id => 123, foo => 'bar' } );

    my $ref = MongoDB::DBRef->new( db => 'fake_db_does_not_exist', 'ref', 'fake_coll_does_not_exist', id => 123 );
    throws_ok { $ref->fetch } qr/Can't fetch DBRef without a MongoClient/;

    $ref->client( $conn );
    throws_ok { $ref->fetch } qr/No such database fake_db_does_not_exist/;

    $ref->db( 'test' );
    throws_ok { $ref->fetch } qr/No such collection fake_coll_does_not_exist/;

    $ref->ref( 'test_coll' );
    
    my $doc = $ref->fetch;
    is $doc->{_id}, 123;
    is $doc->{foo}, 'bar';

    $conn->get_database( 'test' )->drop;
}
