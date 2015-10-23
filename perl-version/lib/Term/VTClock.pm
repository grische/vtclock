package Term::VTClock;

our $VERSION = "1.0.0";

use Curses;
use List::Util qw(min max);
use POSIX qw(strftime);

sub new {
    my ($class, @args) = @_;
    my $self = {};
    bless($self, $class);
    return $self;
}

my $CHARS;
BEGIN {
    $CHARS = {
	"0" => [" XXX ",
		"X   X",
		"X  xx",
		"x x x",
		"xx  x",
		"x   x",
		" xxx "],
	"1" => ["  x  ",
		" xx  ",
		"  x  ",
		"  x  ",
		"  x  ",
		"  x  ",
		" xxx "],
	"2" => [" xxx ",
		"x   x",
		"    x",
		"   x ",
		"  x  ",
		" x   ",
		"xxxxx"],
	"3" => ["xxxxx",
		"   x ",
		"  x  ",
		"   x ",
		"    x",
		"x   x",
		" xxx "],
	"4" => ["   x ",
		"  xx ",
		" x x ",
		"x  x ",
		"xxxxx",
		"   x ",
		"   x "],
	"5" => ["xxxxx",
		"x    ",
		"xxxx ",
		"    x",
		"    x",
		"x   x",
		" xxx "],
	"6" => ["  xx ",
		" x   ",
		"x    ",
		"xxxx ",
		"x   x",
		"x   x",
		" xxx "],
	"7" => ["xxxxx",
		"    x",
		"   x ",
		"  x  ",
		" x   ",
		" x   ",
		" x   "],
	"8" => [" xxx ",
		"x   x",
		"x   x",
		" xxx ",
		"x   x",
		"x   x",
		" xxx "],
	"9" => [" xxx ",
		"x   x",
		"x   x",
		" xxxx",
		"    x",
		"   x ",
		" xx  "],
	":" => [" ",
		" ",
		"x",
		" ",
		"x",
		" ",
		" "],
    };
}

sub char_width {
    my ($self, $char) = @_;
    return max map { length($_) } @{$CHARS->{$char}};
}

sub char_height {
    my ($self, $char) = @_;
    return scalar @{$CHARS->{$char}};
}

sub max_char_width {
    my ($self, @chars) = @_;
    return max map { $self->char_width($_) } @chars;
}

sub max_char_height {
    my ($self, @chars) = @_;
    return max map { $self->char_height($_) } @chars;
}

sub digit_width {
    my ($self) = @_;
    return $self->max_char_width("0" .. "9");
}

sub digit_height {
    my ($self) = @_;
    return $self->max_char_height("0" .. "9");
}

sub colon_width {
    my ($self) = @_;
    return $self->char_width(":");
}

sub colon_height {
    my ($self) = @_;
    return $self->char_height(":");
}

sub make_digit_window {
    my ($self) = @_;
    my $w = $self->digit_width();
    my $h = $self->digit_height();
    my $window = subwin($self->{cl},
			$h, $w + 1,
			$self->{starty},
			$self->{startx});
    $self->{startx} += $w + $self->{space};
    return $window;
}

sub make_colon_window {
    my ($self) = @_;
    my $w = $self->colon_width();
    my $h = $self->colon_height();
    my $window = subwin($self->{cl},
			$h, $w + 1,
			$self->{starty},
			$self->{startx});
    $self->{startx} += $w + $self->{space};
    return $window;
}

sub draw_char {
    my ($self, $w, $char) = @_;
    my $string = join("\n", @{$CHARS->{$char}});

    # mvwin($w, 0, 0);
    addstr($w, 0, 0, $string);
}

use Time::HiRes qw(usleep gettimeofday);

sub delay {
    my ($self) = @_;
    my ($sec, $usec) = gettimeofday();
    usleep(1000000 - $usec);
}

sub run {
    my ($self) = @_;

    initscr();
    cbreak();
    noecho();
    nonl();
    timeout(curscr, 50);

    $SIG{__DIE__} = sub {
	endwin();
	CORE::die(@_);
    };

    $self->{space} = 2;

    $self->{cl_height} = $self->max_char_height("0" .. "9", ":");
    $self->{cl_width} = $self->digit_width() * 6 + $self->colon_width() * 2 + $self->{space} * 7 + 1;

    $self->{x} = int((COLS()  - $self->{cl_width})  / 2);
    $self->{y} = int((LINES() - $self->{cl_height}) / 2);

    if (LINES() < ($self->{cl_height} + 2) || COLS() < ($self->{cl_width})) {
	endwin();
	die(sprintf("Screen (%d x %d) is too small (minimum is %d x %d).\n",
		    COLS(), LINES(),
		    $self->{cl_width}, $self->{cl_height} + 2
		   ));
    }

    $self->{startx} = $self->{x};
    $self->{starty} = $self->{y};

    $self->{updown}    = (LINES() > $self->{cl_height}) ? 1 : 0;
    $self->{leftright} = (COLS()  > $self->{cl_width})  ? 1 : 0;

    $self->{cl}  = newwin($self->{cl_height}, $self->{cl_width}, $self->{y}, $self->{x});
    $self->{cld} = newwin($self->{cl_height}, $self->{cl_width}, $self->{y}, $self->{x});

    $self->{h1} = $self->make_digit_window();
    $self->{h2} = $self->make_digit_window();
    $self->{c1} = $self->make_colon_window();
    $self->{m1} = $self->make_digit_window();
    $self->{m2} = $self->make_digit_window();
    $self->{c2} = $self->make_colon_window();
    $self->{s1} = $self->make_digit_window();
    $self->{s2} = $self->make_digit_window();

    curs_set(0);

    while (1) {
	my $time_string = strftime("%H:%M:%S", localtime());

	$self->draw_char($self->{h1}, substr($time_string, 0, 1));
	$self->draw_char($self->{h2}, substr($time_string, 1, 1));
	$self->draw_char($self->{c1}, ":");
	$self->draw_char($self->{m1}, substr($time_string, 3, 1));
	$self->draw_char($self->{m2}, substr($time_string, 4, 1));
	$self->draw_char($self->{c2}, ":");
	$self->draw_char($self->{s1}, substr($time_string, 6, 1));
	$self->draw_char($self->{s2}, substr($time_string, 7, 1));

	mvwin($self->{cl}, $self->{y}, $self->{x});
	noutrefresh($self->{cl});
	doupdate();

	$self->pollkey();
	$self->delay();
    }

    endwin();
}

sub pollkey {
    my ($self) = @_;
    my $key = getch(curscr);
    if ($key eq chr(12) || $key eq chr(18) || $key eq KEY_REFRESH) {
	redrawwin(curscr);
	refresh(curscr);
    }
}

1;
