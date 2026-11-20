# Passwords in MK

A user's password can be kept in two ways.  Both work side by side in one BBS, and nothing is forced:

| | Plain (the DOS way) | Hashed |
|---|---|---|
| Where | the `Pwd` field of `users.bbs` | `*` in the `Pwd` field, and a hash block in the user's `extusers.bbs` record |
| Length | up to 15 characters, no blanks | up to 50 characters, blanks and `/` allowed |
| Case | not case sensitive | exactly as typed (see "Converted passwords" below) |
| Readable from the files | yes | no: a salted PBKDF2-HMAC-SHA256 hash (20000 iterations by default) |
| Other BBS programs that read `users.bbs` | work | cannot check it |

Hashed passwords exist **only in MK configurations** (a directory with `config.mk`, or `bbsconfig.json`).  With a Remote
Access, QuickBBS or SuperBBS configuration the feature is off whatever the data says, so a sysop who runs MK next to
other BBS software loses nothing.

## The setting

`mkconfig` → General → Security → Options → **Hashed Passwords** (shown only for an MK configuration):

| Value | Meaning |
|---|---|
| **No** (default) | passwords stay as they are; new and changed ones are plain |
| **New** | a new password (new user) or a changed one (the *Your settings > Password* command, the user editor) is stored as a hash; plain passwords stay plain until their owner changes them |
| **All** | as New, and a plain password is converted to a hash when its owner logs on with it |

It is stored in `COption2` of `config.mk` (`csPwdHash`, `csPwdConvert`), so it is also in `bbsconfig.json`.

A hashed account **stays hashed**: with the setting back at No, a changed password is still a hash, and nothing ever turns a
hash back into plain text.

## What the caller notices

* Logging on works as before.  A hashed account takes the password exactly as typed; the whole text is tried first (blanks
  and a slash are part of it), then the first word without a `/door` suffix, as the DOS version took it.
* Changing the password asks for up to 50 characters on a hashed account (15 on a plain one) and refuses a password shorter
  than the minimum length of the configuration.  `*` cannot be a password: it is the marker.
* `mk -Q`, the login of QWK network systems, uses the same check.
* A hash made at fewer iterations than the current setting is renewed at the next successful log-on.

## What the sysop notices

* The user editor (`mkusered`) shows `(hashed)`.  Typing a new password over it sets a new one (a hash again).
* `DOOR.SYS` and the control code that shows the password (`C` in the menu screens) give the word **`unavailable`** for a
  hashed account.  Doors that need the real password will not work for those users.
* The log no longer writes the password that was typed wrongly (it said `Incorrect Password : <text>`; now only
  `Incorrect Password`).
* A `*` with no usable hash (a damaged `extusers.bbs`) lets nobody in; the sysop sets a new password in `mkusered`.

## Converted passwords

A plain password was always compared in upper case, so a user may have typed it in any case.  When it is converted (by the
setting **All**, or by `mkpwconv -h`) the hash is of the **upper case** form and is marked with a flag, and the log-on tries
the password as typed first and then in upper case.  The owner can go on typing it in any case.  A password the user sets
afterwards is exact.

## Converting the whole user base: `mkpwconv`

Neither setting converts users who never log on.  For those:

1. **One-time: expand `extusers.bbs`.**  The extended user record has a block for the hash (and 128 bytes kept for later), so
   it is longer than the DOS record.  `mk` and `mkusered` refuse to run on the old size and say so.  Run once:

   ```
   MK=/bbs/ra mkpwconv -x
   ```

   Every record gets an empty hash block; the passwords are untouched.  The old file is kept as `extusers.bbs.old`.
   (`ExitInfo.Bbs`, which doors read, keeps its old layout.)

2. **Look first:**

   ```
   MK=/bbs/ra mkpwconv -h -n          # counts, changes nothing
   ```

3. **Stop the callers** (stop `mklisten` or wait until no node is in use) and convert:

   ```
   MK=/bbs/ra mkpwconv -h             # all users
   MK=/bbs/ra mkpwconv -h -u "Some Name"   # one user
   ```

   | Option | |
   |---|---|
   | `-n` | dry run |
   | `-u "name"` | one user (not case sensitive) |
   | `-v` | list the users converted |
   | `-i n` | iterations (default 20000; higher is slower at every log-on; a hash takes about 0.14 s at the default, so 1000 users take a few minutes) |
   | `-f` | go on although callers are on line |

   Before it writes, `mkpwconv` copies `users.bbs` and `extusers.bbs` to `users.bbs.pwbak` and `extusers.bbs.pwbak`, and it
   refuses to run while either exists, so a backup is never replaced.  **A hash cannot be turned back: the backup is the way
   back.**  It also refuses when `useron.bbs` shows a caller on line (the BBS writes the user record back at log-off and
   would restore the old password), when the directory is not an MK configuration, and when `extusers.bbs` still has the
   old size.

Exit status: 0 done or nothing to do, 1 a file could not be read or written, 2 a size that fits no record, 3 a backup is in the
way, 4 not an MK configuration or `-x` needed, 5 callers on line.

## Notes for sysops who run other software

* Do not convert a user base that Remote Access, QuickBBS or SuperBBS also reads from the same `users.bbs`: they would see
  `*` as the password.
* Moving back: restore `users.bbs` and `extusers.bbs` from the `.pwbak` files (any password set after the conversion is lost),
  or give the affected users new plain passwords in a configuration with the setting at No.

## Where it is in the code

`src/MKPwd.pas` (SHA-256, HMAC, PBKDF2 and the hash block), `Struct.MK` (`PwHashType`, `ExtUserType`), `MKDoor.pas`
(`CheckUserPwd`, `ChangeUserPwd`), `MKName.pas` (the user editor), `MKPwConv.pas` (the conversion).  Tests: `tests/pwdtest.pas`,
`tests/pwusertest.pas`, `tests/pwlogintest.py`, `tests/pwconvtest.py`.
