#pragma once
namespace hc {
enum class Status { waiting, ready, unsupported, installFailed };
Status status();
void initialize();
void setIgnoreTraps(bool enabled);
void setFreezeTimer(bool enabled);
bool ignoreTraps();
bool freezeTimer();
}
