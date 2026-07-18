import { Box, Snackbar, Typography } from '@mui/material';
import { useCallback, useRef, useState, type FormEvent, type ReactElement } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';

import { AppError } from '@/core/error/app-error';
import { ROUTES } from '@/core/router/routes';

import { toServerDateTime, toValues } from './coupon-form-values';
import {
  CouponForm,
  type CouponFormErrors,
  type CouponFormValues,
} from '../components/coupon-form';
import { useCouponMutation } from '../hooks/use-coupon-mutation';
import type { CouponResponse } from '../models/coupon-response';
import type { DiscountType } from '../models/discount-type';
import type { CouponRepository } from '../repositories/coupon-repository';
import { couponValidators } from '../validators/coupon-validators';

const UNEXPECTED_MESSAGE = 'An unexpected error occurred';

interface CouponFormPageProps {
  readonly repository: CouponRepository;
}

interface NavigationState {
  readonly coupon?: CouponResponse;
}

/**
 * The create / edit coupon screen — the React analog of the Flutter coupon
 * form screen (sprint-11-plan Task 05), mirroring `BrandFormPage` (Sprint 10)
 * verbatim. Edit mode is carried via router `state` (the `go_router` `extra`
 * analog) as the **full** `CouponResponse` — `GET /coupons` already returns
 * the same shape the write endpoints do, so no separate detail fetch is
 * needed (unlike the product aggregate, Sprint 11 Task 04). A fresh visit
 * with no state is create mode.
 *
 * On success it navigates back to [ROUTES.coupons] with a success message in
 * `state`; the list page remounts fresh there and re-fetches on mount, which
 * *is* the "reload the list from the server" this task requires — no explicit
 * cross-hook reload wiring is needed.
 */
export function CouponFormPage({ repository }: CouponFormPageProps): ReactElement {
  const location = useLocation();
  const navigate = useNavigate();
  const editingCoupon = (location.state as NavigationState | null)?.coupon ?? null;

  const reload = useCallback((): Promise<void> => {
    navigate(ROUTES.coupons, {
      state: { successMessage: editingCoupon !== null ? 'Coupon updated' : 'Coupon created' },
    });
    return Promise.resolve();
  }, [navigate, editingCoupon]);

  const mutation = useCouponMutation(repository, reload);

  const [values, setValues] = useState<CouponFormValues>(() => toValues(editingCoupon));
  const [errors, setErrors] = useState<CouponFormErrors>({});
  const [errorMessage, setErrorMessage] = useState<string>();
  const codeInputRef = useRef<HTMLInputElement>(null);
  const nameInputRef = useRef<HTMLInputElement>(null);
  const descriptionInputRef = useRef<HTMLInputElement>(null);
  const discountValueInputRef = useRef<HTMLInputElement>(null);
  const minOrderAmountInputRef = useRef<HTMLInputElement>(null);
  const maxDiscountAmountInputRef = useRef<HTMLInputElement>(null);
  const startAtInputRef = useRef<HTMLInputElement>(null);
  const endAtInputRef = useRef<HTMLInputElement>(null);
  const usageLimitInputRef = useRef<HTMLInputElement>(null);

  function handleFieldChange(
    field: Exclude<keyof CouponFormValues, 'discountType' | 'enabled'>,
    value: string,
  ): void {
    setValues((prev) => ({ ...prev, [field]: value }));
  }

  function handleDiscountTypeChange(discountType: DiscountType): void {
    setValues((prev) => ({ ...prev, discountType }));
  }

  function handleEnabledChange(enabled: boolean): void {
    setValues((prev) => ({ ...prev, enabled }));
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault();
    const codeError = couponValidators.code(values.code);
    const nameError = couponValidators.name(values.name);
    const descriptionError = couponValidators.description(values.description);
    const discountValueError = couponValidators.discountValue(values.discountValue);
    const minOrderAmountError = couponValidators.minOrderAmount(values.minOrderAmount);
    const maxDiscountAmountError = couponValidators.maxDiscountAmount(values.maxDiscountAmount);
    const startAtError = couponValidators.startAt(values.startAt);
    const endAtError = couponValidators.endAt(values.endAt);
    const usageLimitError = couponValidators.usageLimit(values.usageLimit);
    setErrors({
      code: codeError,
      name: nameError,
      description: descriptionError,
      discountValue: discountValueError,
      minOrderAmount: minOrderAmountError,
      maxDiscountAmount: maxDiscountAmountError,
      startAt: startAtError,
      endAt: endAtError,
      usageLimit: usageLimitError,
    });
    if (codeError !== undefined) {
      codeInputRef.current?.focus();
      return;
    }
    if (nameError !== undefined) {
      nameInputRef.current?.focus();
      return;
    }
    if (descriptionError !== undefined) {
      descriptionInputRef.current?.focus();
      return;
    }
    if (discountValueError !== undefined) {
      discountValueInputRef.current?.focus();
      return;
    }
    if (minOrderAmountError !== undefined) {
      minOrderAmountInputRef.current?.focus();
      return;
    }
    if (maxDiscountAmountError !== undefined) {
      maxDiscountAmountInputRef.current?.focus();
      return;
    }
    if (startAtError !== undefined) {
      startAtInputRef.current?.focus();
      return;
    }
    if (endAtError !== undefined) {
      endAtInputRef.current?.focus();
      return;
    }
    if (usageLimitError !== undefined) {
      usageLimitInputRef.current?.focus();
      return;
    }

    const request = {
      code: values.code.trim(),
      name: values.name.trim(),
      description: values.description.trim().length > 0 ? values.description.trim() : undefined,
      discountType: values.discountType,
      discountValue: Number(values.discountValue),
      minOrderAmount: Number(values.minOrderAmount),
      maxDiscountAmount:
        values.maxDiscountAmount.trim().length > 0 ? Number(values.maxDiscountAmount) : undefined,
      startAt: toServerDateTime(values.startAt),
      endAt: toServerDateTime(values.endAt),
      usageLimit: values.usageLimit.trim().length > 0 ? Number(values.usageLimit) : undefined,
      enabled: values.enabled,
    };
    try {
      if (editingCoupon !== null) {
        await mutation.update(editingCoupon.id, request);
      } else {
        await mutation.create(request);
      }
    } catch (error) {
      setErrorMessage(error instanceof AppError ? error.message : UNEXPECTED_MESSAGE);
    }
  }

  return (
    <Box>
      <Typography variant="h4" component="h1" gutterBottom>
        {editingCoupon !== null ? 'Edit coupon' : 'New coupon'}
      </Typography>
      <CouponForm
        values={values}
        errors={errors}
        disabled={mutation.isMutating}
        submitLabel={editingCoupon !== null ? 'Save' : 'Create'}
        codeInputRef={codeInputRef}
        nameInputRef={nameInputRef}
        descriptionInputRef={descriptionInputRef}
        discountValueInputRef={discountValueInputRef}
        minOrderAmountInputRef={minOrderAmountInputRef}
        maxDiscountAmountInputRef={maxDiscountAmountInputRef}
        startAtInputRef={startAtInputRef}
        endAtInputRef={endAtInputRef}
        usageLimitInputRef={usageLimitInputRef}
        onFieldChange={handleFieldChange}
        onDiscountTypeChange={handleDiscountTypeChange}
        onEnabledChange={handleEnabledChange}
        onSubmit={(event) => {
          void handleSubmit(event);
        }}
        onCancel={() => navigate(ROUTES.coupons)}
      />
      <Snackbar
        open={errorMessage !== undefined}
        autoHideDuration={6000}
        onClose={() => setErrorMessage(undefined)}
        message={errorMessage}
      />
    </Box>
  );
}
