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

## Limits: locking and expiry

Both work for **MK users in MK configurations**, plain or hashed password alike, and both are **off until the sysop turns them on**
(`mkconfig` > General > Security > Options; they are stored with a marker, so the bytes that an older `config.mk` has in those places are
never taken for settings).

| Setting | Meaning |
|---|---|
| **Lock After Failures** | wrong passwords in a row, over all calls, after which the account is locked (0 = never) |
| **Locked For (minutes)** | how long a locked account stays locked (15 when not set) |
| **Password Expires (days)** | a password is good for this many days (0 = never) |
| **Warn Before Expiry (days)** | the caller is told at log-on when the password has this many days or fewer left (0 = no warning) |

(`Password Tries`, the wrong passwords in one call before the line is dropped, is the old setting and works as before.)

**Locking.**  Every wrong password is counted for the account and kept at once in `extusers.bbs` (only the state, not the rest of
the record), so dropping the line and calling again does not start a new count.  The count of `Lock After Failures` locks the
account for `Locked For` minutes.  While it is locked **no password is taken, the right one included**, and the caller sees the
ordinary "incorrect password" and nothing that says there is a lock (so a stranger cannot find out which names exist); the log
says `The account of X is locked for N minute(s)` and, for every try, `Locked account X tried a password`.  A good password
resets the count; the failures there were since the last good log-on are told to the caller ("Wrong passwords typed for your
account since your last log-on: 3") and logged.  The first wrong password after a lock that is over is a new count.  The login
of QWK network systems (`mk -Q`) counts and locks in the same way.  In `mkusered` an account shows `[LOCKED]`, and the
**Locked** switch of the edit form unlocks it (and forgets the failures) or locks it by hand.

**Expiry.**  The day a password was set is kept in the same state, and every way of setting one sets it (a new user, *Your
settings > Password*, the editor, the forced change below); the conversion to a hash does not, and nor does a hash that is renewed.  A
password whose date is not known (an account from before) starts its clock at its next good log-on: nobody is made to change at
once.  After `Password Expires` days the caller who gives the right password must choose a new one before anything else (it must
differ from the old one and meet the minimum length; three tries, then the call ends and nothing changes).  A QWK network system is
never asked (nobody is there to answer).

**The login guard of `mklisten`** is a second, separate limit: it counts failed log-ons **by address** and keeps a stranger out
before a node is used (`"loginguard"` in `mklisten.json`, see `MKLISTEN.md`).

The state is in the hash block of the user's `extusers.bbs` record (`PwStateType` in `Struct.MK`: `Changed`, `Fails`, `FailTime`,
`LockUntil`; it took 13 of the 128 reserved bytes, the record keeps its size).  `tests/pwstate.pas` shows or sets it for tests.
The texts are in the language files (prompts 537 to 542); a language file without them gives the English words.

## Notes for sysops who run other software

* Do not convert a user base that Remote Access, QuickBBS or SuperBBS also reads from the same `users.bbs`: they would see
  `*` as the password.
* Moving back: restore `users.bbs` and `extusers.bbs` from the `.pwbak` files (any password set after the conversion is lost),
  or give the affected users new plain passwords in a configuration with the setting at No.

## Where it is in the code

`src/MKPwd.pas` (SHA-256, HMAC, PBKDF2 and the hash block), `Struct.MK` (`PwHashType`, `ExtUserType`), `MKDoor.pas`
(`CheckUserPwd`, `ChangeUserPwd`, `PwdLocked`, `NoteBadPwd`, `PwdDaysLeft`), `MKLogOn.pas` (`TryPassword`, `PasswordNotices`), `MKName.pas` (the user editor), `MKPwConv.pas` (the conversion).  Tests: `tests/pwdtest.pas`,
`tests/pwusertest.pas`, `tests/pwlogintest.py`, `tests/pwlimittest.py`, `tests/loginguardtest.py`, `tests/pwconvtest.py`.
