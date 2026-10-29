<?php
/**
 * Managed by wordpress-plugin-boilerplate/tooling - fix there first, then run bin/sync-tooling.sh
 *
 * Token scan of the free build Freemius generated. Comments and strings are ignored, so a
 * docblock that mentions a __premium_only name is not reported.
 *
 *   php free-build-scan.php <free-plugin-dir> [<premium-plugin-dir>] [<ignore-file>]
 *
 * Prints "ERROR <kind> <file>:<line> <detail>" or "WARN ..." per finding; exits 1 on any ERROR.
 *   leak-def      ERROR a function, method or class named like premium code survived. Freemius
 *                 strips only names containing exactly "__premium_only", so a typo
 *                 (premum_only, _premium_only, premium__only) ships the paid code to wordpress.org.
 *   guard-left    ERROR is__premium_only() or can_use_premium_code__premium_only() still in an if
 *                 condition. Freemius removes the blocks these guard; one left behind means the
 *                 stripper did not recognise the condition (often a compound one), so the premium
 *                 branch shipped. WARN when the call is not a condition (it runs, returns false).
 *   dangling-call ERROR a call to a __premium_only function or method that the free build, the
 *                 Freemius SDK included, no longer defines. Fatal the moment that line runs.
 *   only-premium  ERROR (with the premium dir) a function or class defined only in the plugin's
 *                 premium code is used by the free build. Also fatal when it runs.
 * A name the free build checks with function_exists(), class_exists() or method_exists() is
 * treated as guarded and not reported as dangling-call or only-premium.
 *
 * The ignore file (the project's .freemius-free-scan-ignore) lists accepted findings, one per
 * line as "<kind> <name> <reason>", e.g. "only-premium qpp_stripe_build_session_args guarded by
 * function_exists('qpp_stripe_create_session') in the same if". A line with no reason is refused,
 * so every exception says why it is safe. leak-def cannot be ignored.
 */

$free    = rtrim( $argv[1] ?? '', '/' );
$premium = rtrim( $argv[2] ?? '', '/' );
$ignore  = array();
if ( ! empty( $argv[3] ) && is_file( $argv[3] ) ) {
	foreach ( file( $argv[3], FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES ) as $l ) {
		$l = trim( $l );
		if ( '' === $l || '#' === $l[0] ) {
			continue;
		}
		$parts = preg_split( '/\s+/', $l, 3 );
		if ( count( $parts ) < 3 || 'leak-def' === $parts[0] ) {
			fwrite( STDERR, "Refused ignore line (needs '<kind> <name> <reason>', and leak-def is never ignored): $l\n" );
			exit( 2 );
		}
		$ignore[ $parts[0] . ' ' . strtolower( $parts[1] ) ] = true;
	}
}
if ( '' === $free || ! is_dir( $free ) ) {
	fwrite( STDERR, "Usage: php free-build-scan.php <free-plugin-dir> [<premium-plugin-dir>]\n" );
	exit( 2 );
}

const NOISE = array( T_WHITESPACE, T_COMMENT, T_DOC_COMMENT );

/**
 * Scans every PHP file under $dir.
 * Returns [defs, calls, guarded, sdk_defs]: defs maps lowercase name => [file, line, own] where
 * own is false for vendor code; calls are [name, file, line, kind, in_if]; guarded is the set of
 * names passed to *_exists(); sdk_defs holds definitions from the Freemius SDK, which is not
 * reported on but does define the SDK's own __premium_only methods.
 */
function scan( $dir ) {
	$defs = $calls = $guarded = $sdk = array();
	$it   = new RecursiveIteratorIterator( new RecursiveDirectoryIterator( $dir, FilesystemIterator::SKIP_DOTS ) );
	foreach ( $it as $f ) {
		$file = $f->getPathname();
		$rel  = substr( $file, strlen( $dir ) + 1 );
		if ( substr( $file, -4 ) !== '.php' || preg_match( '#(^|/)(node_modules|tests?)/#', $rel ) ) {
			continue;
		}
		$is_sdk = (bool) preg_match( '#(^|/)freemius/#', $rel );
		$own    = ! preg_match( '#(^|/)vendor/#', $rel );
		$code   = array_values(
			array_filter(
				@token_get_all( file_get_contents( $file ) ),
				function ( $t ) {
					return ! is_array( $t ) || ! in_array( $t[0], NOISE, true );
				}
			)
		);
		$n      = count( $code );
		for ( $i = 0; $i < $n; $i++ ) {
			$t = $code[ $i ];
			if ( ! is_array( $t ) || T_STRING !== $t[0] ) {
				continue;
			}
			$lc   = strtolower( $t[1] );
			$prev = $code[ $i - 1 ] ?? null;
			$next = $code[ $i + 1 ] ?? null;
			$pid  = is_array( $prev ) ? $prev[0] : $prev;
			if ( in_array( $pid, array( T_FUNCTION, T_CLASS, T_INTERFACE, T_TRAIT ), true ) || ( defined( 'T_ENUM' ) && T_ENUM === $pid ) ) {
				if ( $is_sdk ) {
					$sdk[ $lc ] = true;
				} else {
					$defs[ $lc ] = array( $rel, $t[2], $own );
				}
				continue;
			}
			if ( $is_sdk ) {
				continue;
			}
			if ( '(' === $next && in_array( $lc, array( 'function_exists', 'class_exists', 'method_exists' ), true ) ) {
				// The guarded name is the first (function/class_exists) or second (method_exists) string argument.
				for ( $j = $i + 2, $args = 0; $j < $n && ')' !== $code[ $j ]; $j++ ) {
					if ( is_array( $code[ $j ] ) && T_CONSTANT_ENCAPSED_STRING === $code[ $j ][0] ) {
						$guarded[ strtolower( trim( $code[ $j ][1], '\'"\\' ) ) ] = true;
					}
				}
				continue;
			}
			$obj = in_array( $pid, array( T_OBJECT_OPERATOR, T_DOUBLE_COLON ), true ) || ( defined( 'T_NULLSAFE_OBJECT_OPERATOR' ) && T_NULLSAFE_OBJECT_OPERATOR === $pid );
			if ( '(' === $next ) {
				$kind = $obj ? 'method' : ( T_NEW === $pid ? 'class' : 'function' );
			} elseif ( T_NEW === $pid || ( is_array( $next ) && T_DOUBLE_COLON === $next[0] ) ) {
				$kind = 'class';
			} else {
				continue;
			}
			$calls[] = array( $t[1], $rel, $t[2], $kind, in_if( $code, $i ) );
		}
	}
	return array( $defs, $calls, $guarded, $sdk );
}

/** True when token $i sits inside the parentheses of an if or elseif condition. */
function in_if( $code, $i ) {
	for ( $depth = 0, $j = $i - 1; $j >= 0; $j-- ) {
		$t = $code[ $j ];
		if ( in_array( $t, array( ';', '{', '}' ), true ) ) {
			return false;
		}
		if ( ')' === $t ) {
			$depth++;
		} elseif ( '(' === $t ) {
			if ( 0 === $depth ) {
				$p = $code[ $j - 1 ] ?? null;
				if ( is_array( $p ) && in_array( $p[0], array( T_IF, T_ELSEIF ), true ) ) {
					return true;
				}
			} else {
				$depth--;
			}
		}
	}
	return false;
}

list( $fdefs, $fcalls, $guarded, $sdk ) = scan( $free );
$errors                                 = array();
$warns                                  = array();

foreach ( $fdefs as $lc => $where ) {
	if ( preg_match( '/prem\w*only|premium_?onl/i', $lc ) ) {
		$errors[] = "leak-def {$where[0]}:{$where[1]} {$lc} is defined in the free build (Freemius strips only names containing exactly __premium_only)";
	}
}
foreach ( $fcalls as $c ) {
	list( $name, $file, $line, $kind, $in_if ) = $c;
	$lc                                        = strtolower( $name );
	if ( in_array( $lc, array( 'is__premium_only', 'can_use_premium_code__premium_only' ), true ) ) {
		if ( $in_if ) {
			$errors[] = "guard-left {$file}:{$line} {$name}() is still in an if condition in the free build, so the premium block it guards shipped";
		} else {
			$warns[] = "guard-left {$file}:{$line} {$name}() is still in the free build outside an if (it runs and returns false; use can_use_premium_code() if that is intended)";
		}
	} elseif ( false !== strpos( $lc, '__premium_only' ) && ! isset( $fdefs[ $lc ] ) && ! isset( $sdk[ $lc ] ) && ! isset( $guarded[ $lc ] ) ) {
		$errors[] = "dangling-call {$file}:{$line} {$name}() is called but not defined in the free build (fatal when this line runs)";
	}
}

if ( '' !== $premium && is_dir( $premium ) ) {
	list( $pdefs ) = scan( $premium );
	foreach ( $fcalls as $c ) {
		list( $name, $file, $line, $kind ) = $c;
		$lc                                = strtolower( $name );
		// Methods are left out: their names collide across classes, so a match proves nothing.
		if ( 'method' !== $kind && isset( $pdefs[ $lc ] ) && $pdefs[ $lc ][2] && ! isset( $fdefs[ $lc ] ) && ! isset( $sdk[ $lc ] )
			&& ! isset( $guarded[ $lc ] ) && false === strpos( $lc, '__premium_only' ) ) {
			$errors[] = "only-premium {$file}:{$line} {$name} ({$kind}) is defined only in the premium build ({$pdefs[$lc][0]})";
		}
	}
}

foreach ( $errors as $k => $e ) {
	// "<kind> <file>:<line> <name>..." - the name is the third field, without any "()".
	$f = explode( ' ', $e, 4 );
	if ( isset( $ignore[ $f[0] . ' ' . strtolower( rtrim( $f[2], '()' ) ) ] ) ) {
		$warns[] = "ignored $e";
		unset( $errors[ $k ] );
	}
}
foreach ( $errors as $e ) {
	echo "ERROR $e\n";
}
foreach ( $warns as $w ) {
	echo "WARN $w\n";
}
exit( $errors ? 1 : 0 );
