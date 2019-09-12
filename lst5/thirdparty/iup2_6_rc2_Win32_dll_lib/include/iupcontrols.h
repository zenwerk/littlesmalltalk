/** \file
 * \brief initializes iupdial, iupgauge, iuptabs, iupcb, iupgc and iupval
 * controls.
 *
 * See Copyright Notice in iup.h
 */

#ifndef __IUPCONTROLS_H
#define __IUPCONTROLS_H

#include "iupcb.h"
#include "iupcbox.h"
#include "iupcells.h"
#include "iupcolorbar.h"
#include "iupdial.h"
#include "iupgauge.h"
#include "iupgc.h"
#include "iupgetparam.h"
#include "iupmask.h"
#include "iupmatrix.h"
#include "iupsbox.h"
#include "iupspin.h"
#include "iuptabs.h"
#include "iuptree.h"
#include "iupval.h"

#ifdef __cplusplus
extern "C"
{
#endif

  int IupControlsOpen(void);
  void IupControlsClose(void);

  void IupImageLibOpen(void);
  void IupImageLibClose(void);

#ifdef __cplusplus
}
#endif

#endif
